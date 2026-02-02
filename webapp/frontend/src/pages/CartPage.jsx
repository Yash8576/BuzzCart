import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Minus, Plus, Trash2, ShoppingBag, ArrowRight, ArrowLeft, CreditCard } from 'lucide-react';
import { cn } from '../lib/utils';
import { useCart } from "../contexts/CartContext.jsx";
import { Button } from '../components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '../components/ui/card';
import { Separator } from '../components/ui/separator';
import { toast } from 'sonner';

export default function CartPage() {
  const navigate = useNavigate();
  const { cart, updateQuantity, removeFromCart, clearCart, loading } = useCart();
  const [updating, setUpdating] = useState(null);

  const handleQuantityChange = async (productId, newQuantity) => {
    setUpdating(productId);
    try {
      await updateQuantity(productId, newQuantity);
    } catch {
      toast.error('Failed to update quantity');
    } finally {
      setUpdating(null);
    }
  };

  const handleRemove = async (productId) => {
    setUpdating(productId);
    try {
      await removeFromCart(productId);
      toast.success('Item removed from cart');
    } catch {
      toast.error('Failed to remove item');
    } finally {
      setUpdating(null);
    }
  };

  const handleCheckout = () => {
    toast.success('Proceeding to checkout!');
    // In a real app, this would navigate to checkout flow
  };

  if (cart.items.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-center" data-testid="empty-cart">
        <ShoppingBag className="w-20 h-20 text-muted-foreground mb-6" />
        <h1 className="font-heading text-2xl font-bold mb-2">Your cart is empty</h1>
        <p className="text-muted-foreground mb-6">Add some products to get started!</p>
        <Button onClick={() => navigate('/shop')} className="gap-2 rounded-full" data-testid="continue-shopping-btn">
          Continue Shopping
          <ArrowRight className="w-4 h-4" />
        </Button>
      </div>
    );
  }

  return (
    <div data-testid="cart-page">
      <div className="flex items-center gap-4 mb-8">
        <Button variant="ghost" size="icon" onClick={() => navigate(-1)}>
          <ArrowLeft className="w-5 h-5" />
        </Button>
        <h1 className="font-heading text-3xl font-bold">Your Cart</h1>
        <span className="text-muted-foreground">({cart.item_count} items)</span>
      </div>

      <div className="grid lg:grid-cols-3 gap-8">
        {/* Cart Items */}
        <div className="lg:col-span-2 space-y-4">
          {cart.items.map((item, index) => (
            <Card 
              key={item.product.id}
              className="overflow-hidden animate-fade-in"
              style={{ animationDelay: `${index * 50}ms` }}
              data-testid={`cart-item-${item.product.id}`}
            >
              <CardContent className="p-4">
                <div className="flex gap-4">
                  <div 
                    className="w-24 h-24 rounded-lg overflow-hidden bg-muted flex-shrink-0 cursor-pointer"
                    onClick={() => navigate(`/shop/${item.product.id}`)}
                  >
                    <img 
                      src={item.product.images?.[0] || '/placeholder.jpg'} 
                      alt={item.product.title}
                      className="w-full h-full object-cover"
                    />
                  </div>
                  
                  <div className="flex-1 min-w-0">
                    <h3 
                      className="font-medium line-clamp-1 cursor-pointer hover:underline"
                      onClick={() => navigate(`/shop/${item.product.id}`)}
                    >
                      {item.product.title}
                    </h3>
                    <p className="text-sm text-muted-foreground">{item.product.seller_name}</p>
                    <p className="text-lg font-bold mt-2">${item.product.price?.toFixed(2)}</p>
                  </div>

                  <div className="flex flex-col items-end justify-between">
                    <Button
                      variant="ghost"
                      size="icon"
                      className="text-destructive hover:text-destructive"
                      onClick={() => handleRemove(item.product.id)}
                      disabled={updating === item.product.id}
                      data-testid={`remove-item-${item.product.id}`}
                    >
                      <Trash2 className="w-4 h-4" />
                    </Button>
                    
                    <div className="flex items-center gap-2">
                      <Button 
                        variant="outline" 
                        size="icon"
                        className="h-8 w-8"
                        onClick={() => handleQuantityChange(item.product.id, item.quantity - 1)}
                        disabled={item.quantity <= 1 || updating === item.product.id}
                      >
                        <Minus className="w-3 h-3" />
                      </Button>
                      <span className="w-8 text-center font-medium">{item.quantity}</span>
                      <Button 
                        variant="outline" 
                        size="icon"
                        className="h-8 w-8"
                        onClick={() => handleQuantityChange(item.product.id, item.quantity + 1)}
                        disabled={updating === item.product.id}
                      >
                        <Plus className="w-3 h-3" />
                      </Button>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}

          <Button 
            variant="ghost" 
            className="text-destructive hover:text-destructive"
            onClick={clearCart}
          >
            Clear Cart
          </Button>
        </div>

        {/* Order Summary */}
        <div className="lg:col-span-1">
          <Card className="sticky top-24" data-testid="order-summary">
            <CardHeader>
              <CardTitle>Order Summary</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Subtotal</span>
                <span>${cart.subtotal.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">Shipping</span>
                <span className="text-success-green">Free</span>
              </div>
              <Separator />
              <div className="flex justify-between font-bold text-lg">
                <span>Total</span>
                <span>${cart.total.toFixed(2)}</span>
              </div>

              <Button 
                className="w-full h-12 rounded-full text-base gap-2"
                onClick={handleCheckout}
                data-testid="checkout-btn"
              >
                <CreditCard className="w-5 h-5" />
                Checkout
              </Button>

              <Button 
                variant="outline"
                className="w-full rounded-full"
                onClick={() => navigate('/shop')}
              >
                Continue Shopping
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}