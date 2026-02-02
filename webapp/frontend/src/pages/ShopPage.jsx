import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { ShoppingBag, Star, Filter, SortAsc, ArrowLeft, Heart, Share2, Minus, Plus, ChevronLeft, ChevronRight } from 'lucide-react';
import { cn } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Card, CardContent } from '../components/ui/card';
import { Badge } from '../components/ui/badge';
import { Skeleton } from '../components/ui/skeleton';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../components/ui/select';
import { useCart } from "../contexts/CartContext.jsx";
import { toast } from 'sonner';

const API = `${import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000'}/api`;

const categories = [
  { value: '', label: 'All Categories' },
  { value: 'tech', label: 'Tech' },
  { value: 'fashion', label: 'Fashion' },
  { value: 'beauty', label: 'Beauty' },
  { value: 'home', label: 'Home' },
  { value: 'sports', label: 'Sports' },
];

function ProductDetail({ productId, onBack }) {
  const { addToCart } = useCart();
  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [quantity, setQuantity] = useState(1);
  const [currentImage, setCurrentImage] = useState(0);

  useEffect(() => {
    fetchProduct();
  }, [productId]);

  const fetchProduct = async () => {
    try {
      const response = await axios.get(`${API}/products/${productId}`);
      setProduct(response.data);
    } catch (err) {
      console.error('Failed to fetch product:', err);
      toast.error('Product not found');
      onBack();
    } finally {
      setLoading(false);
    }
  };

  const handleAddToCart = async () => {
    try {
      await addToCart(productId, quantity);
      toast.success(`Added ${quantity} item(s) to cart!`);
    } catch {
      toast.error('Failed to add to cart');
    }
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <Button variant="ghost" onClick={onBack} className="gap-2">
          <ArrowLeft className="w-4 h-4" /> Back
        </Button>
        <div className="grid md:grid-cols-2 gap-8">
          <Skeleton className="aspect-square rounded-xl" />
          <div className="space-y-4">
            <Skeleton className="h-8 w-3/4" />
            <Skeleton className="h-6 w-1/4" />
            <Skeleton className="h-24 w-full" />
          </div>
        </div>
      </div>
    );
  }

  if (!product) return null;

  return (
    <div className="animate-fade-in" data-testid="product-detail">
      <Button variant="ghost" onClick={onBack} className="gap-2 mb-6" data-testid="back-btn">
        <ArrowLeft className="w-4 h-4" /> Back to Shop
      </Button>

      <div className="grid md:grid-cols-2 gap-8">
        {/* Image gallery */}
        <div className="space-y-4">
          <div className="aspect-square rounded-xl overflow-hidden bg-muted relative group">
            <img 
              src={product.images?.[currentImage] || '/placeholder.jpg'} 
              alt={product.title}
              className="w-full h-full object-cover"
            />
            {product.images?.length > 1 && (
              <>
                <Button
                  variant="ghost"
                  size="icon"
                  className="absolute left-2 top-1/2 -translate-y-1/2 bg-white/80 hover:bg-white opacity-0 group-hover:opacity-100 transition-opacity"
                  onClick={() => setCurrentImage(i => i > 0 ? i - 1 : product.images.length - 1)}
                >
                  <ChevronLeft className="w-5 h-5" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  className="absolute right-2 top-1/2 -translate-y-1/2 bg-white/80 hover:bg-white opacity-0 group-hover:opacity-100 transition-opacity"
                  onClick={() => setCurrentImage(i => i < product.images.length - 1 ? i + 1 : 0)}
                >
                  <ChevronRight className="w-5 h-5" />
                </Button>
              </>
            )}
          </div>
          {product.images?.length > 1 && (
            <div className="flex gap-2 overflow-x-auto">
              {product.images.map((img, idx) => (
                <button
                  key={idx}
                  className={cn(
                    "w-20 h-20 rounded-lg overflow-hidden flex-shrink-0 border-2 transition-colors",
                    currentImage === idx ? "border-primary" : "border-transparent"
                  )}
                  onClick={() => setCurrentImage(idx)}
                >
                  <img src={img} alt="" className="w-full h-full object-cover" />
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Product info */}
        <div className="space-y-6">
          <div>
            <Badge variant="secondary" className="mb-2">{product.category}</Badge>
            <h1 className="font-heading text-3xl font-bold">{product.title}</h1>
            <div className="flex items-center gap-2 mt-2">
              <div className="flex items-center gap-1">
                <Star className="w-4 h-4 fill-yellow-400 text-yellow-400" />
                <span className="font-medium">{product.rating?.toFixed(1) || '0.0'}</span>
              </div>
              <span className="text-muted-foreground">({product.reviews_count} reviews)</span>
              <span className="text-muted-foreground">•</span>
              <span className="text-muted-foreground">{product.views} views</span>
            </div>
          </div>

          <p className="text-3xl font-bold">${product.price?.toFixed(2)}</p>

          <p className="text-muted-foreground leading-relaxed">{product.description}</p>

          <div className="flex items-center gap-4">
            <span className="text-sm font-medium">Quantity:</span>
            <div className="flex items-center gap-2">
              <Button 
                variant="outline" 
                size="icon"
                onClick={() => setQuantity(q => Math.max(1, q - 1))}
                disabled={quantity <= 1}
              >
                <Minus className="w-4 h-4" />
              </Button>
              <span className="w-12 text-center font-medium">{quantity}</span>
              <Button 
                variant="outline" 
                size="icon"
                onClick={() => setQuantity(q => q + 1)}
              >
                <Plus className="w-4 h-4" />
              </Button>
            </div>
          </div>

          <div className="flex gap-3">
            <Button 
              className="flex-1 h-12 rounded-full text-base"
              onClick={handleAddToCart}
              data-testid="add-to-cart-btn"
            >
              <ShoppingBag className="w-5 h-5 mr-2" />
              Add to Cart
            </Button>
            <Button variant="outline" size="icon" className="h-12 w-12 rounded-full">
              <Heart className="w-5 h-5" />
            </Button>
            <Button variant="outline" size="icon" className="h-12 w-12 rounded-full">
              <Share2 className="w-5 h-5" />
            </Button>
          </div>

          <div className="pt-6 border-t border-border">
            <p className="text-sm text-muted-foreground">
              Sold by <span className="font-medium text-foreground">{product.seller_name}</span>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function ShopPage() {
  const navigate = useNavigate();
  const { productId } = useParams();
  const { addToCart } = useCart();
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [category, setCategory] = useState('');
  const [sort, setSort] = useState('newest');

  useEffect(() => {
    if (!productId) {
      fetchProducts();
    }
  }, [category, sort, productId]);

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams();
      if (category) params.append('category', category);
      if (sort) params.append('sort', sort);
      const response = await axios.get(`${API}/products?${params}`);
      setProducts(response.data);
    } catch (err) {
      console.error('Failed to fetch products:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleAddToCart = async (productId, e) => {
    e.stopPropagation();
    try {
      await addToCart(productId);
      toast.success('Added to cart!');
    } catch {
      toast.error('Failed to add to cart');
    }
  };

  if (productId) {
    return <ProductDetail productId={productId} onBack={() => navigate('/shop')} />;
  }

  return (
    <div data-testid="shop-page">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="font-heading text-3xl font-bold">Shop</h1>
          <p className="text-muted-foreground mt-1">Discover products from creators</p>
        </div>

        <div className="flex gap-3">
          <Select value={category} onValueChange={setCategory}>
            <SelectTrigger className="w-[160px]" data-testid="category-select">
              <Filter className="w-4 h-4 mr-2" />
              <SelectValue placeholder="Category" />
            </SelectTrigger>
            <SelectContent>
              {categories.map((cat) => (
                <SelectItem key={cat.value} value={cat.value}>{cat.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <Select value={sort} onValueChange={setSort}>
            <SelectTrigger className="w-[140px]" data-testid="sort-select">
              <SortAsc className="w-4 h-4 mr-2" />
              <SelectValue placeholder="Sort" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="newest">Newest</SelectItem>
              <SelectItem value="price_low">Price: Low</SelectItem>
              <SelectItem value="price_high">Price: High</SelectItem>
              <SelectItem value="popular">Popular</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {loading ? (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
          {[...Array(8)].map((_, i) => (
            <Skeleton key={i} className="aspect-[3/4] rounded-xl" />
          ))}
        </div>
      ) : products.length === 0 ? (
        <div className="flex flex-col items-center justify-center min-h-[50vh] text-center">
          <ShoppingBag className="w-16 h-16 text-muted-foreground mb-4" />
          <h2 className="text-xl font-heading font-bold mb-2">No products found</h2>
          <p className="text-muted-foreground">Try a different category or check back later!</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
          {products.map((product, index) => (
            <Card 
              key={product.id}
              className="overflow-hidden group cursor-pointer hover:shadow-lg transition-all animate-fade-in"
              style={{ animationDelay: `${index * 50}ms` }}
              onClick={() => navigate(`/shop/${product.id}`)}
              data-testid={`product-card-${product.id}`}
            >
              <div className="aspect-[3/4] relative overflow-hidden bg-muted">
                <img 
                  src={product.images?.[0] || '/placeholder.jpg'} 
                  alt={product.title}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                <Button
                  size="icon"
                  className="absolute bottom-3 right-3 opacity-0 group-hover:opacity-100 transition-all bg-white text-black hover:bg-white/90 rounded-full"
                  onClick={(e) => handleAddToCart(product.id, e)}
                  data-testid={`quick-add-${product.id}`}
                >
                  <ShoppingBag className="w-4 h-4" />
                </Button>
                {product.rating > 0 && (
                  <Badge className="absolute top-3 left-3 bg-white/90 text-black hover:bg-white">
                    <Star className="w-3 h-3 fill-yellow-400 text-yellow-400 mr-1" />
                    {product.rating.toFixed(1)}
                  </Badge>
                )}
              </div>
              <CardContent className="p-4">
                <p className="font-medium line-clamp-1">{product.title}</p>
                <p className="text-lg font-bold mt-1">${product.price?.toFixed(2)}</p>
                <p className="text-sm text-muted-foreground mt-1">{product.seller_name}</p>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}