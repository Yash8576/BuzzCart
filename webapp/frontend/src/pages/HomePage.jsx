import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { Play, ShoppingBag, Heart, Eye, Loader2 } from 'lucide-react';
import { cn } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Card, CardContent } from '../components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '../components/ui/avatar';
import { Skeleton } from '../components/ui/skeleton';
import { useCart } from "../contexts/CartContext.jsx";
import { toast } from 'sonner';

const API = `${import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000'}/api`;

export default function HomePage() {
  const navigate = useNavigate();
  const { addToCart } = useCart();
  const [feed, setFeed] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchFeed();
  }, []);

  const fetchFeed = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API}/feed`);
      setFeed(response.data);
    } catch (err) {
      setError('Failed to load feed');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleAddToCart = async (productId, e) => {
    e.stopPropagation();
    try {
      await addToCart(productId);
      toast.success('Added to cart!');
    } catch (err) {
      toast.error('Failed to add to cart');
    }
  };

  const renderFeedItem = (item, index) => {
    const { type, data } = item;

    if (type === 'product') {
      return (
        <Card 
          key={`product-${data.id}`}
          className="overflow-hidden group cursor-pointer hover:shadow-lg transition-all animate-fade-in"
          style={{ animationDelay: `${index * 50}ms` }}
          onClick={() => navigate(`/shop/${data.id}`)}
          data-testid={`feed-product-${data.id}`}
        >
          <div className="aspect-square relative overflow-hidden bg-muted">
            <img 
              src={data.images?.[0] || '/placeholder.jpg'} 
              alt={data.title}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
            <Button
              size="icon"
              className="absolute bottom-3 right-3 opacity-0 group-hover:opacity-100 transition-all bg-white text-black hover:bg-white/90 rounded-full"
              onClick={(e) => handleAddToCart(data.id, e)}
              data-testid={`add-cart-${data.id}`}
            >
              <ShoppingBag className="w-4 h-4" />
            </Button>
          </div>
          <CardContent className="p-4">
            <p className="font-medium line-clamp-1">{data.title}</p>
            <p className="text-lg font-bold mt-1">${data.price?.toFixed(2)}</p>
            <div className="flex items-center gap-2 mt-2 text-sm text-muted-foreground">
              <Eye className="w-4 h-4" />
              <span>{data.views || 0} views</span>
            </div>
          </CardContent>
        </Card>
      );
    }

    if (type === 'video') {
      return (
        <Card 
          key={`video-${data.id}`}
          className="overflow-hidden group cursor-pointer hover:shadow-lg transition-all col-span-1 md:col-span-2 animate-fade-in"
          style={{ animationDelay: `${index * 50}ms` }}
          onClick={() => navigate(`/videos/${data.id}`)}
          data-testid={`feed-video-${data.id}`}
        >
          <div className="aspect-video relative overflow-hidden bg-muted">
            <img 
              src={data.thumbnail} 
              alt={data.title}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
            />
            <div className="absolute inset-0 bg-black/30 flex items-center justify-center">
              <div className="w-16 h-16 rounded-full bg-white/90 flex items-center justify-center group-hover:scale-110 transition-transform">
                <Play className="w-7 h-7 text-black ml-1" fill="currentColor" />
              </div>
            </div>
            <div className="absolute bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-black/80 to-transparent">
              <div className="flex items-center gap-3">
                <Avatar className="w-8 h-8 border-2 border-white">
                  <AvatarImage src={data.creator_avatar} />
                  <AvatarFallback>{data.creator_name?.[0]}</AvatarFallback>
                </Avatar>
                <div className="text-white">
                  <p className="font-medium line-clamp-1">{data.title}</p>
                  <p className="text-sm opacity-80">{data.creator_name}</p>
                </div>
              </div>
            </div>
          </div>
        </Card>
      );
    }

    if (type === 'reel') {
      return (
        <Card 
          key={`reel-${data.id}`}
          className="overflow-hidden group cursor-pointer hover:shadow-lg transition-all animate-fade-in"
          style={{ animationDelay: `${index * 50}ms` }}
          onClick={() => navigate(`/reels?id=${data.id}`)}
          data-testid={`feed-reel-${data.id}`}
        >
          <div className="aspect-[3/4] relative overflow-hidden bg-muted">
            <img 
              src={data.thumbnail} 
              alt={data.caption}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent" />
            <div className="absolute top-3 right-3 flex items-center gap-1 bg-black/50 text-white text-xs px-2 py-1 rounded-full">
              <Play className="w-3 h-3" fill="currentColor" />
              Reel
            </div>
            <div className="absolute bottom-0 left-0 right-0 p-4">
              <div className="flex items-center gap-2 text-white mb-2">
                <Avatar className="w-6 h-6 border border-white">
                  <AvatarImage src={data.creator_avatar} />
                  <AvatarFallback>{data.creator_name?.[0]}</AvatarFallback>
                </Avatar>
                <span className="text-sm font-medium">{data.creator_name}</span>
              </div>
              <p className="text-white text-sm line-clamp-2">{data.caption}</p>
              <div className="flex items-center gap-4 mt-2 text-white/80 text-xs">
                <span className="flex items-center gap-1">
                  <Heart className="w-3 h-3" /> {data.likes}
                </span>
                <span className="flex items-center gap-1">
                  <Eye className="w-3 h-3" /> {data.views}
                </span>
              </div>
            </div>
          </div>
        </Card>
      );
    }

    return null;
  };

  if (loading) {
    return (
      <div data-testid="home-loading">
        <div className="mb-8">
          <h1 className="font-heading text-3xl md:text-4xl font-bold">Discover</h1>
          <p className="text-muted-foreground mt-1">Shop, watch, and connect</p>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
          {[...Array(8)].map((_, i) => (
            <Skeleton key={i} className="aspect-square rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[50vh] text-center" data-testid="home-error">
        <p className="text-muted-foreground mb-4">{error}</p>
        <Button onClick={fetchFeed}>Try Again</Button>
      </div>
    );
  }

  if (feed.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[50vh] text-center" data-testid="home-empty">
        <ShoppingBag className="w-16 h-16 text-muted-foreground mb-4" />
        <h2 className="text-xl font-heading font-bold mb-2">No content yet</h2>
        <p className="text-muted-foreground mb-4">Check back later for new products and videos!</p>
        <Button onClick={fetchFeed}>Refresh</Button>
      </div>
    );
  }

  return (
    <div data-testid="home-page">
      <div className="mb-8">
        <h1 className="font-heading text-3xl md:text-4xl font-bold">Discover</h1>
        <p className="text-muted-foreground mt-1">Shop, watch, and connect</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
        {feed.map((item, index) => renderFeedItem(item, index))}
      </div>
    </div>
  );
}