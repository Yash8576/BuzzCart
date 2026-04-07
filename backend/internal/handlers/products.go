package handlers

import (
	"buzzcart/internal/cache"
	"buzzcart/internal/database"
	"buzzcart/internal/models"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/lib/pq"
	"github.com/redis/go-redis/v9"
)

const productSelectBase = `
	SELECT
		p.id,
		p.title,
		COALESCE(p.description, ''),
		p.price,
		p.compare_at_price,
		COALESCE(p.currency, 'USD'),
		p.sku,
		COALESCE(p.stock_quantity, 0),
		COALESCE(p.condition, 'new'),
		COALESCE((
			SELECT ARRAY_AGG(pi.image_url ORDER BY pi.display_order)
			FROM product_images pi
			WHERE pi.product_id = p.id
		), ARRAY[]::TEXT[]),
		COALESCE(c.name, ''),
		COALESCE(p.tags, ARRAY[]::TEXT[]),
		p.seller_id,
		COALESCE(u.name, u.username, ''),
		COALESCE((
			SELECT AVG(pr.rating)::FLOAT8
			FROM product_ratings pr
			WHERE pr.product_id = p.id
				AND pr.is_private = false
				AND pr.moderation_status = 'approved'
		), 0),
		COALESCE((
			SELECT COUNT(*)
			FROM product_ratings pr
			WHERE pr.product_id = p.id
				AND pr.is_private = false
				AND pr.moderation_status = 'approved'
		), 0),
		COALESCE((
			SELECT SUM(pa.view_count)
			FROM product_analytics pa
			WHERE pa.product_id = p.id
		), 0),
		COALESCE(p.metadata, '{}'::jsonb),
		p.created_at
	FROM products p
	LEFT JOIN categories c ON c.id = p.category_id
	LEFT JOIN users u ON u.id = p.seller_id
	WHERE p.is_active = TRUE
`

const productSelectLegacy = `
	SELECT
		p.id,
		p.title,
		COALESCE(p.description, ''),
		p.price,
		p.images,
		COALESCE(p.category, ''),
		COALESCE(p.tags, ARRAY[]::TEXT[]),
		p.seller_id,
		COALESCE(p.seller_name, u.name, ''),
		COALESCE(p.rating, 0),
		COALESCE(p.reviews_count, 0),
		COALESCE(p.views, 0),
		p.created_at
	FROM products p
	LEFT JOIN users u ON u.id = p.seller_id
`

func CreateProduct(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ProductCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			log.Printf("[CreateProduct] Invalid request from user %s: %v", userID, err)
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
			return
		}

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()

		req = normalizeProductCreate(req)

		var sellerName string
		var role string
		err := db.QueryRowContext(
			ctx,
			"SELECT COALESCE(name, username, ''), COALESCE(role, 'consumer') FROM users WHERE id = $1",
			userID,
		).Scan(&sellerName, &role)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		if err != nil {
			log.Printf("[CreateProduct] Database error fetching user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}
		if role != string(models.RoleSeller) && role != string(models.RoleAdmin) {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only seller accounts can add products"})
			return
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		productID := uuid.New().String()
		createdAt := time.Now()
		product, categoryName, err := createProductWithSchemaFallback(
			ctx,
			db,
			tx,
			productID,
			userID,
			sellerName,
			createdAt,
			req,
		)
		if err != nil {
			log.Printf("[CreateProduct] Failed to create product for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create product"})
			return
		}

		log.Printf("[CreateProduct] Product %s created successfully by user %s", productID, userID)
		if product.ID == "" {
			c.JSON(http.StatusCreated, gin.H{
				"id":          productID,
				"title":       req.Title,
				"description": req.Description,
				"price":       req.Price,
				"images":      req.Images,
				"category":    categoryName,
				"tags":        req.Tags,
				"seller_id":   userID,
				"seller_name": sellerName,
				"created_at":  createdAt,
				"metadata":    req.Metadata,
			})
			return
		}
		c.JSON(http.StatusCreated, product)
	}
}

func GetProducts(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		category := c.Query("category")
		var (
			rows *sql.Rows
			err  error
		)
		if category != "" {
			rows, err = db.Query(
				productSelectBase+` AND c.name ILIKE $1 ORDER BY p.created_at DESC LIMIT 100`,
				category,
			)
		} else {
			rows, err = db.Query(productSelectBase + ` ORDER BY p.created_at DESC LIMIT 100`)
		}
		if err != nil {
			log.Printf("[GetProducts] primary query failed (category=%q): %v", category, err)
			products, legacyErr := getProductsLegacy(db, category)
			if legacyErr != nil {
				log.Printf("[GetProducts] legacy query failed (category=%q): %v", category, legacyErr)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
				return
			}
			c.JSON(http.StatusOK, products)
			return
		}
		defer rows.Close()

		products := []models.Product{}
		for rows.Next() {
			product, err := scanProduct(rows)
			if err != nil {
				log.Printf("[GetProducts] decode failed: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode products"})
				return
			}
			products = append(products, product)
		}
		if err := rows.Err(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
			return
		}

		c.JSON(http.StatusOK, products)
	}
}

func GetProduct(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		productID := c.Param("product_id")

		product, err := getProductByID(db, productID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}
		if err != nil {
			log.Printf("[GetProduct] primary query failed (product_id=%s): %v", productID, err)
			product, err = getProductByIDLegacy(db, productID)
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
				return
			}
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
				return
			}
		}

		c.JSON(http.StatusOK, product)
	}
}

func UpdateProduct(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		productID := c.Param("product_id")

		var product models.Product
		err := db.QueryRow("SELECT seller_id FROM products WHERE id = $1", productID).Scan(&product.SellerID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
			return
		}

		if product.SellerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		var req models.ProductCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		req = normalizeProductCreate(req)

		ctx, cancel := database.NewContext()
		defer cancel()

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		product, err = updateProductWithSchemaFallback(ctx, db, tx, productID, req)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update product"})
			return
		}

		c.JSON(http.StatusOK, product)
	}
}

func DeleteProduct(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		productID := c.Param("product_id")

		var product models.Product
		err := db.QueryRow("SELECT seller_id FROM products WHERE id = $1", productID).Scan(&product.SellerID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product"})
			return
		}

		if product.SellerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		if _, err := tx.ExecContext(ctx, "DELETE FROM review_helpful_votes WHERE review_id IN (SELECT id FROM product_ratings WHERE product_id = $1)", productID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
			return
		}
		if _, err := tx.ExecContext(ctx, "DELETE FROM product_ratings WHERE product_id = $1", productID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
			return
		}
		if _, err := tx.ExecContext(ctx, "DELETE FROM product_analytics WHERE product_id = $1", productID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
			return
		}
		if _, err := tx.ExecContext(ctx, "DELETE FROM product_images WHERE product_id = $1", productID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
			return
		}

		result, err := tx.ExecContext(ctx, "DELETE FROM products WHERE id = $1", productID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
			return
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Product deleted"})
	}
}

func GetSellerProducts(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		sellerID := c.Param("seller_id")
		requestingUserID := c.GetString("user_id")

		ctx, cancel := database.NewContext()
		defer cancel()

		var visibilityMode string
		var visibilityPreferencesJSON string
		err := db.QueryRowContext(ctx,
			"SELECT COALESCE(visibility_mode, 'public'), COALESCE(visibility_preferences::text, '{\"photos\": true, \"videos\": true, \"reels\": true, \"purchases\": true}') FROM users WHERE id = $1",
			sellerID,
		).Scan(&visibilityMode, &visibilityPreferencesJSON)
		if err != nil {
			visibilityMode = "public"
			visibilityPreferencesJSON = ""
		}

		if requestingUserID != sellerID && !visibilityBucketAllowed(visibilityMode, visibilityPreferencesJSON, contentBucketPurchases, false) {
			c.JSON(http.StatusOK, []models.Product{})
			return
		}

		rows, err := db.Query(
			productSelectBase+` AND p.seller_id = $1 ORDER BY p.created_at DESC`, sellerID,
		)
		if err != nil {
			log.Printf("[GetSellerProducts] primary query failed (seller_id=%s): %v", sellerID, err)
			products, legacyErr := getSellerProductsLegacy(db, sellerID)
			if legacyErr != nil {
				log.Printf("[GetSellerProducts] legacy query failed (seller_id=%s): %v", sellerID, legacyErr)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
				return
			}
			c.JSON(http.StatusOK, products)
			return
		}
		defer rows.Close()

		products := []models.Product{}
		for rows.Next() {
			product, err := scanProduct(rows)
			if err != nil {
				log.Printf("[GetSellerProducts] decode failed (seller_id=%s): %v", sellerID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode products"})
				return
			}
			products = append(products, product)
		}
		if err := rows.Err(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
			return
		}

		c.JSON(http.StatusOK, products)
	}
}

func normalizeProductCreate(req models.ProductCreate) models.ProductCreate {
	req.Title = strings.TrimSpace(req.Title)
	req.Description = strings.TrimSpace(req.Description)
	req.Category = strings.TrimSpace(req.Category)
	if req.Images == nil {
		req.Images = []string{}
	}
	if req.Tags == nil {
		req.Tags = []string{}
	}
	if req.Metadata == nil {
		req.Metadata = map[string]any{}
	}
	req.Condition = strings.ToLower(strings.TrimSpace(req.Condition))
	if req.Condition == "" {
		req.Condition = "new"
	}
	return req
}

func getProductByID(db *sql.DB, productID string) (models.Product, error) {
	return scanProduct(
		db.QueryRow(
			productSelectBase+` AND p.id = $1 LIMIT 1`,
			productID,
		),
	)
}

func getProductByIDLegacy(db *sql.DB, productID string) (models.Product, error) {
	return scanProductLegacy(
		db.QueryRow(
			productSelectLegacy+` WHERE p.id = $1 LIMIT 1`,
			productID,
		),
	)
}

type productScanner interface {
	Scan(dest ...any) error
}

func scanProduct(scanner productScanner) (models.Product, error) {
	product := models.Product{
		Currency:  "USD",
		Condition: "new",
		Images:    []string{},
		Tags:      []string{},
		Metadata:  map[string]any{},
	}

	var (
		compareAtPrice sql.NullFloat64
		sku            sql.NullString
		metadataJSON   []byte
	)

	err := scanner.Scan(
		&product.ID,
		&product.Title,
		&product.Description,
		&product.Price,
		&compareAtPrice,
		&product.Currency,
		&sku,
		&product.StockQuantity,
		&product.Condition,
		pq.Array(&product.Images),
		&product.Category,
		pq.Array(&product.Tags),
		&product.SellerID,
		&product.SellerName,
		&product.Rating,
		&product.ReviewsCount,
		&product.Views,
		&metadataJSON,
		&product.CreatedAt,
	)
	if err != nil {
		return models.Product{}, err
	}

	if compareAtPrice.Valid {
		product.CompareAtPrice = &compareAtPrice.Float64
	}
	if sku.Valid && strings.TrimSpace(sku.String) != "" {
		value := sku.String
		product.SKU = &value
	}
	if len(metadataJSON) > 0 {
		if err := json.Unmarshal(metadataJSON, &product.Metadata); err != nil {
			return models.Product{}, err
		}
	}
	if product.Metadata == nil {
		product.Metadata = map[string]any{}
	}

	return product, nil
}

func scanProductLegacy(scanner productScanner) (models.Product, error) {
	product := models.Product{
		Currency:  "USD",
		Condition: "new",
		Images:    []string{},
		Tags:      []string{},
		Metadata:  map[string]any{},
	}

	err := scanner.Scan(
		&product.ID,
		&product.Title,
		&product.Description,
		&product.Price,
		pq.Array(&product.Images),
		&product.Category,
		pq.Array(&product.Tags),
		&product.SellerID,
		&product.SellerName,
		&product.Rating,
		&product.ReviewsCount,
		&product.Views,
		&product.CreatedAt,
	)
	if err != nil {
		return models.Product{}, err
	}

	return product, nil
}

func getProductsLegacy(db *sql.DB, category string) ([]models.Product, error) {
	query := productSelectLegacy
	args := []any{}
	if strings.TrimSpace(category) != "" {
		query += ` WHERE p.category ILIKE $1`
		args = append(args, category)
	}
	query += ` ORDER BY p.created_at DESC LIMIT 100`
	rows, err := db.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	products := []models.Product{}
	for rows.Next() {
		product, err := scanProductLegacy(rows)
		if err != nil {
			return nil, err
		}
		products = append(products, product)
	}
	return products, rows.Err()
}

func getSellerProductsLegacy(db *sql.DB, sellerID string) ([]models.Product, error) {
	rows, err := db.Query(
		productSelectLegacy+` WHERE p.seller_id = $1 ORDER BY p.created_at DESC`,
		sellerID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	products := []models.Product{}
	for rows.Next() {
		product, err := scanProductLegacy(rows)
		if err != nil {
			return nil, err
		}
		products = append(products, product)
	}
	return products, rows.Err()
}

func createProductWithSchemaFallback(
	ctx context.Context,
	db *sql.DB,
	tx *sql.Tx,
	productID string,
	userID string,
	sellerName string,
	createdAt time.Time,
	req models.ProductCreate,
) (models.Product, string, error) {
	categoryID, categoryName, err := ensureCategoryTx(ctx, tx, req.Category)
	if err == nil {
		metadataJSON, marshalErr := json.Marshal(req.Metadata)
		if marshalErr != nil {
			return models.Product{}, "", marshalErr
		}

		stockQuantity := 0
		if req.StockQuantity != nil && *req.StockQuantity > 0 {
			stockQuantity = *req.StockQuantity
		}

		_, err = tx.ExecContext(
			ctx,
			`INSERT INTO products (
				id, seller_id, category_id, title, description, price, compare_at_price, currency,
				sku, stock_quantity, condition, tags, metadata, is_active, created_at, updated_at
			) VALUES (
				$1, $2, $3, $4, $5, $6, $7, 'USD', $8, $9, $10, $11, $12, TRUE, $13, $13
			)`,
			productID,
			userID,
			categoryID,
			req.Title,
			req.Description,
			req.Price,
			req.CompareAtPrice,
			req.SKU,
			stockQuantity,
			req.Condition,
			pq.Array(req.Tags),
			metadataJSON,
			createdAt,
		)
		if err == nil {
			if err = syncProductImagesTx(ctx, tx, productID, req.Images); err == nil {
				if err = tx.Commit(); err == nil {
					product, reloadErr := getProductByID(db, productID)
					if reloadErr == nil {
						return product, categoryName, nil
					}
					log.Printf("[CreateProduct] Enhanced insert succeeded but reload failed, falling back to partial response: %v", reloadErr)
					return models.Product{}, categoryName, nil
				}
			}
		}
		log.Printf("[CreateProduct] Enhanced schema path failed, falling back to legacy schema: %v", err)
	}

	legacyProduct, legacyErr := createLegacyProduct(ctx, db, productID, userID, sellerName, createdAt, req)
	return legacyProduct, req.Category, legacyErr
}

func createLegacyProduct(
	ctx context.Context,
	db *sql.DB,
	productID string,
	userID string,
	sellerName string,
	createdAt time.Time,
	req models.ProductCreate,
) (models.Product, error) {
	metadataJSON, err := json.Marshal(req.Metadata)
	if err != nil {
		return models.Product{}, err
	}

	_, err = db.ExecContext(
		ctx,
		`INSERT INTO products (
			id, title, description, price, images, category, tags, seller_id, seller_name,
			rating, reviews_count, views, metadata, created_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, 0, 0, 0, $10, $11
		)`,
		productID,
		req.Title,
		req.Description,
		req.Price,
		pq.Array(req.Images),
		req.Category,
		pq.Array(req.Tags),
		userID,
		sellerName,
		metadataJSON,
		createdAt,
	)
	if err != nil {
		_, fallbackErr := db.ExecContext(
			ctx,
			`INSERT INTO products (
				id, title, description, price, images, category, tags, seller_id, seller_name,
				rating, reviews_count, views, created_at
			) VALUES (
				$1, $2, $3, $4, $5, $6, $7, $8, $9, 0, 0, 0, $10
			)`,
			productID,
			req.Title,
			req.Description,
			req.Price,
			pq.Array(req.Images),
			req.Category,
			pq.Array(req.Tags),
			userID,
			sellerName,
			createdAt,
		)
		if fallbackErr != nil {
			return models.Product{}, err
		}
	}

	return getProductByIDLegacy(db, productID)
}

func updateProductWithSchemaFallback(
	ctx context.Context,
	db *sql.DB,
	tx *sql.Tx,
	productID string,
	req models.ProductCreate,
) (models.Product, error) {
	categoryID, _, err := ensureCategoryTx(ctx, tx, req.Category)
	if err == nil {
		metadataJSON, marshalErr := json.Marshal(req.Metadata)
		if marshalErr != nil {
			return models.Product{}, marshalErr
		}

		stockQuantity := 0
		if req.StockQuantity != nil && *req.StockQuantity > 0 {
			stockQuantity = *req.StockQuantity
		}

		_, err = tx.ExecContext(
			ctx,
			`UPDATE products
			 SET title = $1,
			     description = $2,
			     price = $3,
			     compare_at_price = $4,
			     category_id = $5,
			     tags = $6,
			     sku = $7,
			     stock_quantity = $8,
			     condition = $9,
			     metadata = $10,
			     updated_at = $11
			 WHERE id = $12`,
			req.Title,
			req.Description,
			req.Price,
			req.CompareAtPrice,
			categoryID,
			pq.Array(req.Tags),
			req.SKU,
			stockQuantity,
			req.Condition,
			metadataJSON,
			time.Now(),
			productID,
		)
		if err == nil {
			if err = syncProductImagesTx(ctx, tx, productID, req.Images); err == nil {
				if err = tx.Commit(); err == nil {
					return getProductByID(db, productID)
				}
			}
		}
		log.Printf("[UpdateProduct] Enhanced schema path failed, falling back to legacy schema: %v", err)
	}

	metadataJSON, err := json.Marshal(req.Metadata)
	if err != nil {
		return models.Product{}, err
	}

	_, err = db.ExecContext(
		ctx,
		`UPDATE products
		 SET title = $1,
		     description = $2,
		     price = $3,
		     images = $4,
		     category = $5,
		     tags = $6,
		     metadata = $7
		 WHERE id = $8`,
		req.Title,
		req.Description,
		req.Price,
		pq.Array(req.Images),
		req.Category,
		pq.Array(req.Tags),
		metadataJSON,
		productID,
	)
	if err != nil {
		_, fallbackErr := db.ExecContext(
			ctx,
			`UPDATE products
			 SET title = $1,
			     description = $2,
			     price = $3,
			     images = $4,
			     category = $5,
			     tags = $6
			 WHERE id = $7`,
			req.Title,
			req.Description,
			req.Price,
			pq.Array(req.Images),
			req.Category,
			pq.Array(req.Tags),
			productID,
		)
		if fallbackErr != nil {
			return models.Product{}, err
		}
	}

	return getProductByIDLegacy(db, productID)
}

func ensureCategoryTx(ctx context.Context, tx *sql.Tx, category string) (*string, string, error) {
	category = strings.TrimSpace(category)
	if category == "" {
		return nil, "", nil
	}

	categoryID := uuid.New().String()
	now := time.Now()
	slug := slugify(category)
	var resolvedID string
	var resolvedName string

	err := tx.QueryRowContext(
		ctx,
		`INSERT INTO categories (id, name, slug, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $4)
		 ON CONFLICT (slug) DO UPDATE SET
		 	name = EXCLUDED.name,
		 	updated_at = EXCLUDED.updated_at
		 RETURNING id, name`,
		categoryID,
		category,
		slug,
		now,
	).Scan(&resolvedID, &resolvedName)
	if err != nil {
		return nil, "", err
	}

	return &resolvedID, resolvedName, nil
}

func syncProductImagesTx(ctx context.Context, tx *sql.Tx, productID string, imageURLs []string) error {
	if _, err := tx.ExecContext(ctx, "DELETE FROM product_images WHERE product_id = $1", productID); err != nil {
		return err
	}

	for index, imageURL := range imageURLs {
		imageURL = strings.TrimSpace(imageURL)
		if imageURL == "" {
			continue
		}

		if _, err := tx.ExecContext(
			ctx,
			`INSERT INTO product_images (id, product_id, image_url, display_order, is_primary, created_at)
			 VALUES ($1, $2, $3, $4, $5, $6)`,
			uuid.New().String(),
			productID,
			imageURL,
			index,
			index == 0,
			time.Now(),
		); err != nil {
			return err
		}
	}

	return nil
}

func slugify(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	var builder strings.Builder
	lastWasDash := false
	for _, r := range value {
		switch {
		case (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9'):
			builder.WriteRune(r)
			lastWasDash = false
		case !lastWasDash:
			builder.WriteRune('-')
			lastWasDash = true
		}
	}
	slug := strings.Trim(builder.String(), "-")
	if slug == "" {
		return "general"
	}
	return slug
}

// ============================================================================
// REVIEW HANDLERS
// ============================================================================

// CreateReview creates a new product review
func CreateReview(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ReviewCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Check if product exists
		var productExists bool
		err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM products WHERE id = $1)", req.ProductID).Scan(&productExists)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify product"})
			return
		}
		if !productExists {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}

		// Check if user already reviewed this product
		var existingReviewID string
		err = db.QueryRow("SELECT id FROM product_ratings WHERE product_id = $1 AND user_id = $2", req.ProductID, userID).Scan(&existingReviewID)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "You have already reviewed this product", "review_id": existingReviewID})
			return
		} else if err != sql.ErrNoRows {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check existing review"})
			return
		}

		// Check if user has purchased this product to set is_verified_purchase
		var hasPurchased bool
		err = db.QueryRow(
			`SELECT EXISTS(
				SELECT 1 FROM order_items oi
				JOIN orders o ON oi.order_id = o.id
				WHERE o.user_id = $1 
				AND oi.product_id = $2
				AND o.status IN ('delivered', 'completed')
			)`,
			userID, req.ProductID,
		).Scan(&hasPurchased)
		if err != nil {
			// If there's an error checking purchase history, log it but continue
			// The review can still be created, just won't be marked as verified
			hasPurchased = false
		}

		// Create review
		review := models.Review{
			ID:                 uuid.New().String(),
			ProductID:          req.ProductID,
			UserID:             userID,
			Rating:             req.Rating,
			ReviewTitle:        req.ReviewTitle,
			ReviewText:         req.ReviewText,
			IsPrivate:          req.IsPrivate,
			IsVerifiedPurchase: hasPurchased,
			ModerationStatus:   models.ModerationPending, // All new reviews start as pending
			HelpfulCount:       0,
			CreatedAt:          time.Now(),
			UpdatedAt:          time.Now(),
		}

		_, err = db.Exec(
			`INSERT INTO product_ratings (id, product_id, user_id, rating, review_title, review_text, is_verified_purchase, is_private, moderation_status, helpful_count, created_at, updated_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
			review.ID, review.ProductID, review.UserID, review.Rating, review.ReviewTitle, review.ReviewText,
			review.IsVerifiedPurchase, review.IsPrivate, review.ModerationStatus, review.HelpfulCount, review.CreatedAt, review.UpdatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create review"})
			return
		}

		// Update product rating and review count
		updateProductRating(db, req.ProductID)

		// Invalidate cache for ranked reviews
		invalidateReviewCache(req.ProductID)

		// Get user info for response
		db.QueryRow("SELECT name, avatar FROM users WHERE id = $1", userID).Scan(&review.Username, &review.UserAvatar)

		c.JSON(http.StatusCreated, review)
	}
}

// GetProductReviews retrieves all reviews for a specific product
func GetProductReviews(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		productID := c.Param("product_id")

		// Check if product exists
		var productExists bool
		err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM products WHERE id = $1)", productID).Scan(&productExists)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify product"})
			return
		}
		if !productExists {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}

		// Get reviews (only public reviews unless user is authenticated)
		userID := c.GetString("user_id")
		var rows *sql.Rows

		if userID != "" {
			// If authenticated, show all approved public reviews + user's own reviews (any status)
			rows, err = db.Query(
				`SELECT pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
						pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
						pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
						u.name, u.avatar,
						CASE WHEN rhv.user_id IS NOT NULL THEN true ELSE false END as has_voted
				 FROM product_ratings pr
				 JOIN users u ON pr.user_id = u.id
				 LEFT JOIN review_helpful_votes rhv ON rhv.review_id = pr.id AND rhv.user_id = $2
				 WHERE pr.product_id = $1 
				 AND ((pr.moderation_status = 'approved' AND pr.is_private = false) OR pr.user_id = $2)
				 ORDER BY pr.created_at DESC`,
				productID, userID,
			)
		} else {
			// If not authenticated, show only approved public reviews
			rows, err = db.Query(
				`SELECT pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
						pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
						pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
						u.name, u.avatar
				 FROM product_ratings pr
				 JOIN users u ON pr.user_id = u.id
				 WHERE pr.product_id = $1 AND pr.moderation_status = 'approved' AND pr.is_private = false
				 ORDER BY pr.created_at DESC`,
				productID,
			)
		}

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reviews"})
			return
		}
		defer rows.Close()

		var reviews []models.Review
		for rows.Next() {
			var review models.Review
			if userID != "" {
				err := rows.Scan(
					&review.ID, &review.ProductID, &review.UserID, &review.Rating, &review.ReviewTitle, &review.ReviewText,
					&review.IsVerifiedPurchase, &review.IsPrivate, &review.ModerationStatus, &review.ModerationNote,
					&review.ModeratedBy, &review.ModeratedAt, &review.HelpfulCount, &review.CreatedAt, &review.UpdatedAt,
					&review.Username, &review.UserAvatar, &review.HasVoted,
				)
				if err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reviews"})
					return
				}
			} else {
				err := rows.Scan(
					&review.ID, &review.ProductID, &review.UserID, &review.Rating, &review.ReviewTitle, &review.ReviewText,
					&review.IsVerifiedPurchase, &review.IsPrivate, &review.ModerationStatus, &review.ModerationNote,
					&review.ModeratedBy, &review.ModeratedAt, &review.HelpfulCount, &review.CreatedAt, &review.UpdatedAt,
					&review.Username, &review.UserAvatar,
				)
				if err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reviews"})
					return
				}
				review.HasVoted = false
			}
			reviews = append(reviews, review)
		}

		if reviews == nil {
			reviews = []models.Review{}
		}

		c.JSON(http.StatusOK, reviews)
	}
}

// GetProductReviewsRanked retrieves reviews for a product ranked by relationship to the current user
// Ranking logic: Direct followers (weight: 1.0) → Mutual follows (0.7) → Following (0.5) → Public (0.3)
// Results are cached in Redis for 5 minutes
func GetProductReviewsRanked(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		productID := c.Param("product_id")
		userID := c.GetString("user_id")

		// Create cache key based on product and user
		cacheKey := fmt.Sprintf("ranked_reviews:%s:%s", productID, userID)

		// Try to get from cache
		if cachedData, err := cache.Get(cacheKey); err == nil {
			var reviews []models.Review
			if err := json.Unmarshal([]byte(cachedData), &reviews); err == nil {
				c.JSON(http.StatusOK, reviews)
				return
			}
		} else if err != redis.Nil {
			// Log error but continue to fetch from DB
			log.Printf("Redis get error: %v", err)
		}

		// Check if product exists
		var productExists bool
		err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM products WHERE id = $1)", productID).Scan(&productExists)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify product"})
			return
		}
		if !productExists {
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}

		var rows *sql.Rows

		if userID != "" {
			// Authenticated user - rank reviews based on relationship
			rows, err = db.Query(
				`SELECT 
					pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
					pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
					pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
					u.name, u.avatar,
					CASE
						-- Mutual follows: both users follow each other (weight: 0.7)
						WHEN uf_author_follows_user.follower_id IS NOT NULL 
							AND uf_user_follows_author.follower_id IS NOT NULL
						THEN 0.7
						-- Direct followers: review author follows current user (weight: 1.0)
						WHEN uf_author_follows_user.follower_id IS NOT NULL
						THEN 1.0
						-- Following: current user follows review author (weight: 0.5)
						WHEN uf_user_follows_author.follower_id IS NOT NULL
						THEN 0.5
						-- Public: no relationship (weight: 0.3)
						ELSE 0.3
					END as relationship_weight,
					CASE WHEN rhv.user_id IS NOT NULL THEN true ELSE false END as has_voted
				FROM product_ratings pr
				JOIN users u ON pr.user_id = u.id
				LEFT JOIN user_follows uf_author_follows_user 
					ON uf_author_follows_user.follower_id = pr.user_id 
					AND uf_author_follows_user.following_id = $2
				LEFT JOIN user_follows uf_user_follows_author 
					ON uf_user_follows_author.follower_id = $2 
					AND uf_user_follows_author.following_id = pr.user_id
				LEFT JOIN review_helpful_votes rhv ON rhv.review_id = pr.id AND rhv.user_id = $2
				WHERE pr.product_id = $1 
				AND ((pr.moderation_status = 'approved' AND pr.is_private = false) OR pr.user_id = $2)
				ORDER BY relationship_weight DESC, pr.helpful_count DESC, pr.created_at DESC`,
				productID, userID,
			)
		} else {
			// Unauthenticated user - show only approved public reviews, sorted by helpful_count
			rows, err = db.Query(
				`SELECT 
					pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
					pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
					pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
					u.name, u.avatar
				FROM product_ratings pr
				JOIN users u ON pr.user_id = u.id
				WHERE pr.product_id = $1 
				AND pr.moderation_status = 'approved' 
				AND pr.is_private = false
				ORDER BY pr.helpful_count DESC, pr.created_at DESC`,
				productID,
			)
		}

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reviews"})
			return
		}
		defer rows.Close()

		var reviews []models.Review
		for rows.Next() {
			var review models.Review
			var relationshipWeight *float64 // For authenticated users only

			if userID != "" {
				err := rows.Scan(
					&review.ID, &review.ProductID, &review.UserID, &review.Rating, &review.ReviewTitle, &review.ReviewText,
					&review.IsVerifiedPurchase, &review.IsPrivate, &review.ModerationStatus, &review.ModerationNote,
					&review.ModeratedBy, &review.ModeratedAt, &review.HelpfulCount, &review.CreatedAt, &review.UpdatedAt,
					&review.Username, &review.UserAvatar, &relationshipWeight, &review.HasVoted,
				)
				if err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reviews"})
					return
				}
			} else {
				err := rows.Scan(
					&review.ID, &review.ProductID, &review.UserID, &review.Rating, &review.ReviewTitle, &review.ReviewText,
					&review.IsVerifiedPurchase, &review.IsPrivate, &review.ModerationStatus, &review.ModerationNote,
					&review.ModeratedBy, &review.ModeratedAt, &review.HelpfulCount, &review.CreatedAt, &review.UpdatedAt,
					&review.Username, &review.UserAvatar,
				)
				if err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reviews"})
					return
				}
				review.HasVoted = false
			}
			reviews = append(reviews, review)
		}

		if reviews == nil {
			reviews = []models.Review{}
		}

		// Cache the results for 5 minutes
		if reviewsJSON, err := json.Marshal(reviews); err == nil {
			if err := cache.Set(cacheKey, string(reviewsJSON), 5*time.Minute); err != nil {
				log.Printf("Redis set error: %v", err)
			}
		}

		c.JSON(http.StatusOK, reviews)
	}
}

// GetReview retrieves a specific review by ID
func GetReview(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		reviewID := c.Param("review_id")
		userID := c.GetString("user_id")

		var review models.Review
		err := db.QueryRow(
			`SELECT pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
					pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
					pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
					u.name, u.avatar
			 FROM product_ratings pr
			 JOIN users u ON pr.user_id = u.id
			 WHERE pr.id = $1`,
			reviewID,
		).Scan(
			&review.ID, &review.ProductID, &review.UserID, &review.Rating, &review.ReviewTitle, &review.ReviewText,
			&review.IsVerifiedPurchase, &review.IsPrivate, &review.ModerationStatus, &review.ModerationNote,
			&review.ModeratedBy, &review.ModeratedAt, &review.HelpfulCount, &review.CreatedAt, &review.UpdatedAt,
			&review.Username, &review.UserAvatar,
		)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Review not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch review"})
			return
		}

		// Check privacy: if review is private, only the owner can view it
		if review.IsPrivate && review.UserID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "This review is private"})
			return
		}

		c.JSON(http.StatusOK, review)
	}
}

// UpdateReview updates a review (owner only)
func UpdateReview(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		reviewID := c.Param("review_id")

		// Check if review exists and user is the owner
		var review models.Review
		err := db.QueryRow("SELECT user_id, product_id FROM product_ratings WHERE id = $1", reviewID).Scan(&review.UserID, &review.ProductID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Review not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch review"})
			return
		}

		if review.UserID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to update this review"})
			return
		}

		var req models.ReviewCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Update review
		_, err = db.Exec(
			`UPDATE product_ratings 
			 SET rating = $1, review_title = $2, review_text = $3, is_private = $4, updated_at = $5
			 WHERE id = $6`,
			req.Rating, req.ReviewTitle, req.ReviewText, req.IsPrivate, time.Now(), reviewID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update review"})
			return
		}

		// Update product rating if rating changed
		updateProductRating(db, review.ProductID)

		// Invalidate cache for ranked reviews
		invalidateReviewCache(review.ProductID)

		// Fetch updated review
		err = db.QueryRow(
			`SELECT pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
					pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
					pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
					u.name, u.avatar
			 FROM product_ratings pr
			 JOIN users u ON pr.user_id = u.id
			 WHERE pr.id = $1`,
			reviewID,
		).Scan(
			&review.ID, &review.ProductID, &review.UserID, &review.Rating, &review.ReviewTitle, &review.ReviewText,
			&review.IsVerifiedPurchase, &review.IsPrivate, &review.ModerationStatus, &review.ModerationNote,
			&review.ModeratedBy, &review.ModeratedAt, &review.HelpfulCount, &review.CreatedAt, &review.UpdatedAt,
			&review.Username, &review.UserAvatar,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch updated review"})
			return
		}

		c.JSON(http.StatusOK, review)
	}
}

// DeleteReview deletes a review (owner only)
func DeleteReview(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		reviewID := c.Param("review_id")

		// Check if review exists and user is the owner
		var ownerID, productID string
		err := db.QueryRow("SELECT user_id, product_id FROM product_ratings WHERE id = $1", reviewID).Scan(&ownerID, &productID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Review not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch review"})
			return
		}

		if ownerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to delete this review"})
			return
		}

		// Delete review
		_, err = db.Exec("DELETE FROM product_ratings WHERE id = $1", reviewID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete review"})
			return
		}

		// Update product rating and review count
		updateProductRating(db, productID)

		// Invalidate cache for ranked reviews
		invalidateReviewCache(productID)

		c.JSON(http.StatusOK, gin.H{"message": "Review deleted successfully"})
	}
}

// GetUserReviews retrieves all reviews by a specific user
func GetUserReviews(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		targetUserID := c.Param("user_id")
		currentUserID := c.GetString("user_id")

		// Determine which reviews to show based on privacy
		var rows *sql.Rows
		var err error

		if currentUserID == targetUserID {
			// Show all reviews if viewing own profile
			rows, err = db.Query(
				`SELECT pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
						pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
						pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
						u.name, u.avatar
				 FROM product_ratings pr
				 JOIN users u ON pr.user_id = u.id
				 WHERE pr.user_id = $1
				 ORDER BY pr.created_at DESC`,
				targetUserID,
			)
		} else {
			// Show only approved public reviews for other users
			rows, err = db.Query(
				`SELECT pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
						pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
						pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
						u.name, u.avatar
				 FROM product_ratings pr
				 JOIN users u ON pr.user_id = u.id
				 WHERE pr.user_id = $1 AND pr.is_private = false AND pr.moderation_status = 'approved'
				 ORDER BY pr.created_at DESC`,
				targetUserID,
			)
		}

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reviews"})
			return
		}
		defer rows.Close()

		var reviews []models.Review
		for rows.Next() {
			var review models.Review
			err := rows.Scan(
				&review.ID, &review.ProductID, &review.UserID, &review.Rating, &review.ReviewTitle, &review.ReviewText,
				&review.IsVerifiedPurchase, &review.IsPrivate, &review.ModerationStatus, &review.ModerationNote,
				&review.ModeratedBy, &review.ModeratedAt, &review.HelpfulCount, &review.CreatedAt, &review.UpdatedAt,
				&review.Username, &review.UserAvatar,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reviews"})
				return
			}
			reviews = append(reviews, review)
		}

		if reviews == nil {
			reviews = []models.Review{}
		}

		c.JSON(http.StatusOK, reviews)
	}
}

// UpdateReviewPrivacy updates only the privacy setting of a review
func UpdateReviewPrivacy(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		reviewID := c.Param("review_id")

		// Check if review exists and user is the owner
		var ownerID string
		err := db.QueryRow("SELECT user_id FROM product_ratings WHERE id = $1", reviewID).Scan(&ownerID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Review not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch review"})
			return
		}

		if ownerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized to update this review"})
			return
		}

		var req models.ReviewUpdatePrivacy
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Update privacy setting
		_, err = db.Exec(
			`UPDATE product_ratings SET is_private = $1, updated_at = $2 WHERE id = $3`,
			req.IsPrivate, time.Now(), reviewID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update review privacy"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Review privacy updated successfully", "is_private": req.IsPrivate})
	}
}

// ModerateReview approves or rejects a review (admin/moderator only)
func ModerateReview(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		moderatorID := c.GetString("user_id")
		reviewID := c.Param("review_id")

		// Check if user is admin
		var role string
		err := db.QueryRow("SELECT role FROM users WHERE id = $1", moderatorID).Scan(&role)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify user"})
			return
		}
		if role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only admins can moderate reviews"})
			return
		}

		// Check if review exists
		var exists bool
		err = db.QueryRow("SELECT EXISTS(SELECT 1 FROM product_ratings WHERE id = $1)", reviewID).Scan(&exists)
		if err != nil || !exists {
			c.JSON(http.StatusNotFound, gin.H{"error": "Review not found"})
			return
		}

		var req models.ReviewModerate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Update moderation status
		moderatedAt := time.Now()
		var productID string
		err = db.QueryRow(
			`UPDATE product_ratings 
			 SET moderation_status = $1, moderation_note = $2, moderated_by = $3, moderated_at = $4, updated_at = $5
			 WHERE id = $6
			 RETURNING product_id`,
			req.Status, req.Note, moderatorID, moderatedAt, time.Now(), reviewID,
		).Scan(&productID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to moderate review"})
			return
		}

		// Update product rating if approved (recalculate with new approved reviews)
		if req.Status == models.ModerationApproved {
			updateProductRating(db, productID)
		}

		// Invalidate cache for ranked reviews
		invalidateReviewCache(productID)

		c.JSON(http.StatusOK, gin.H{
			"message":           "Review moderated successfully",
			"moderation_status": req.Status,
			"moderated_at":      moderatedAt,
		})
	}
}

// GetPendingReviews retrieves all pending reviews for moderation (admin only)
func GetPendingReviews(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		// Check if user is admin
		var role string
		err := db.QueryRow("SELECT role FROM users WHERE id = $1", userID).Scan(&role)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify user"})
			return
		}
		if role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only admins can view pending reviews"})
			return
		}

		rows, err := db.Query(
			`SELECT pr.id, pr.product_id, pr.user_id, pr.rating, pr.review_title, pr.review_text, 
					pr.is_verified_purchase, pr.is_private, pr.moderation_status, pr.moderation_note,
					pr.moderated_by, pr.moderated_at, pr.helpful_count, pr.created_at, pr.updated_at,
					u.name, u.avatar
			 FROM product_ratings pr
			 JOIN users u ON pr.user_id = u.id
			 WHERE pr.moderation_status = 'pending'
			 ORDER BY pr.created_at ASC`,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch pending reviews"})
			return
		}
		defer rows.Close()

		var reviews []models.Review
		for rows.Next() {
			var review models.Review
			err := rows.Scan(
				&review.ID, &review.ProductID, &review.UserID, &review.Rating, &review.ReviewTitle, &review.ReviewText,
				&review.IsVerifiedPurchase, &review.IsPrivate, &review.ModerationStatus, &review.ModerationNote,
				&review.ModeratedBy, &review.ModeratedAt, &review.HelpfulCount, &review.CreatedAt, &review.UpdatedAt,
				&review.Username, &review.UserAvatar,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reviews"})
				return
			}
			reviews = append(reviews, review)
		}

		if reviews == nil {
			reviews = []models.Review{}
		}

		c.JSON(http.StatusOK, reviews)
	}
}

// MarkReviewHelpful allows users to mark a review as helpful
func MarkReviewHelpful(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		reviewID := c.Param("review_id")

		// Check if review exists and is public/approved
		var review models.Review
		err := db.QueryRow(
			`SELECT id, product_id, user_id, is_private, moderation_status, helpful_count 
			 FROM product_ratings WHERE id = $1`,
			reviewID,
		).Scan(&review.ID, &review.ProductID, &review.UserID, &review.IsPrivate, &review.ModerationStatus, &review.HelpfulCount)

		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Review not found"})
			return
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch review"})
			return
		}

		// Users cannot vote on their own reviews
		if review.UserID == userID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot mark your own review as helpful"})
			return
		}

		// Only approved public reviews can be marked helpful
		if review.ModerationStatus != models.ModerationApproved || review.IsPrivate {
			c.JSON(http.StatusForbidden, gin.H{"error": "This review is not available for voting"})
			return
		}

		// Check if user already voted
		var voteExists bool
		err = db.QueryRow(
			`SELECT EXISTS(SELECT 1 FROM review_helpful_votes WHERE review_id = $1 AND user_id = $2)`,
			reviewID, userID,
		).Scan(&voteExists)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check vote status"})
			return
		}

		if voteExists {
			// Remove vote (toggle off)
			_, err = db.Exec(
				`DELETE FROM review_helpful_votes WHERE review_id = $1 AND user_id = $2`,
				reviewID, userID,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove helpful vote"})
				return
			}

			// Decrement helpful_count
			err = db.QueryRow(
				`UPDATE product_ratings SET helpful_count = helpful_count - 1 WHERE id = $1 RETURNING helpful_count`,
				reviewID,
			).Scan(&review.HelpfulCount)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update helpful count"})
				return
			}

			// Invalidate cache for ranked reviews
			invalidateReviewCache(review.ProductID)

			c.JSON(http.StatusOK, gin.H{
				"message":       "Helpful vote removed",
				"helpful_count": review.HelpfulCount,
				"voted":         false,
			})
		} else {
			// Add vote
			_, err = db.Exec(
				`INSERT INTO review_helpful_votes (review_id, user_id, voted_at) VALUES ($1, $2, $3)`,
				reviewID, userID, time.Now(),
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add helpful vote"})
				return
			}

			// Increment helpful_count
			err = db.QueryRow(
				`UPDATE product_ratings SET helpful_count = helpful_count + 1 WHERE id = $1 RETURNING helpful_count`,
				reviewID,
			).Scan(&review.HelpfulCount)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update helpful count"})
				// Invalidate cache for ranked reviews
				invalidateReviewCache(review.ProductID)

				return
			}

			c.JSON(http.StatusOK, gin.H{
				"message":       "Review marked as helpful",
				"helpful_count": review.HelpfulCount,
				"voted":         true,
			})
		}
	}
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// updateProductRating recalculates and updates the average rating and review count for a product
// Only counts approved and public reviews
func updateProductRating(db *sql.DB, productID string) error {
	_ = db
	_ = productID
	// Ratings are derived at read time from product_ratings, so there is nothing
	// to persist on the products table here.
	return nil
}

// invalidateReviewCache invalidates all cached ranked reviews for a product
// This should be called whenever reviews are created, updated, deleted, or voted on
func invalidateReviewCache(productID string) {
	// Pattern to match all cached reviews for this product (for all users)
	pattern := fmt.Sprintf("ranked_reviews:%s:*", productID)

	// Use Redis SCAN to find and delete all matching keys
	rdb := cache.GetClient()
	if rdb == nil {
		return
	}

	ctx := context.Background()
	iter := rdb.Scan(ctx, 0, pattern, 0).Iterator()
	for iter.Next(ctx) {
		if err := rdb.Del(ctx, iter.Val()).Err(); err != nil {
			log.Printf("Failed to delete cache key %s: %v", iter.Val(), err)
		}
	}
	if err := iter.Err(); err != nil {
		log.Printf("Error scanning cache keys: %v", err)
	}
}
