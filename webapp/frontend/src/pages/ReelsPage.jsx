import { useState, useEffect, useRef } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { Heart, MessageCircle, Share2, ShoppingBag, Volume2, VolumeX, Pause, Play } from 'lucide-react';
import { cn } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '../components/ui/avatar';
import { useCart } from "../contexts/CartContext.jsx";
import { toast } from 'sonner';

const API = `${import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000'}/api`;

function ReelCard({ reel, isActive, onLike }) {
  const navigate = useNavigate();
  const { addToCart } = useCart();
  const videoRef = useRef(null);
  const [muted, setMuted] = useState(true);
  const [playing, setPlaying] = useState(false);
  const [liked, setLiked] = useState(false);

  useEffect(() => {
    if (videoRef.current) {
      if (isActive) {
        videoRef.current.play().catch(() => {});
        setPlaying(true);
      } else {
        videoRef.current.pause();
        videoRef.current.currentTime = 0;
        setPlaying(false);
      }
    }
  }, [isActive]);

  const togglePlay = () => {
    if (videoRef.current) {
      if (playing) {
        videoRef.current.pause();
      } else {
        videoRef.current.play();
      }
      setPlaying(!playing);
    }
  };

  const handleLike = async () => {
    if (liked) return;
    setLiked(true);
    onLike(reel.id);
  };

  const handleAddToCart = async (productId) => {
    try {
      await addToCart(productId);
      toast.success('Added to cart!');
    } catch {
      toast.error('Failed to add to cart');
    }
  };

  return (
    <div className="relative w-full h-full snap-start snap-always flex-shrink-0 bg-black">
      <video
        ref={videoRef}
        src={reel.url}
        poster={reel.thumbnail}
        loop
        muted={muted}
        playsInline
        className="absolute inset-0 w-full h-full object-cover"
        onClick={togglePlay}
        data-testid={`reel-video-${reel.id}`}
      />

      {/* Play/Pause indicator */}
      {!playing && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/20">
          <div className="w-20 h-20 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center">
            <Play className="w-10 h-10 text-white ml-1" fill="white" />
          </div>
        </div>
      )}

      {/* Gradient overlay */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent pointer-events-none" />

      {/* Right side actions */}
      <div className="absolute right-3 bottom-32 flex flex-col items-center gap-5">
        <Button
          variant="ghost"
          size="icon"
          className={cn(
            "w-12 h-12 rounded-full bg-white/10 backdrop-blur-sm hover:bg-white/20",
            liked && "text-red-500"
          )}
          onClick={handleLike}
          data-testid={`like-reel-${reel.id}`}
        >
          <Heart className={cn("w-6 h-6", liked && "fill-current")} />
        </Button>
        <span className="text-white text-xs">{reel.likes + (liked ? 1 : 0)}</span>

        <Button
          variant="ghost"
          size="icon"
          className="w-12 h-12 rounded-full bg-white/10 backdrop-blur-sm hover:bg-white/20"
        >
          <MessageCircle className="w-6 h-6 text-white" />
        </Button>

        <Button
          variant="ghost"
          size="icon"
          className="w-12 h-12 rounded-full bg-white/10 backdrop-blur-sm hover:bg-white/20"
        >
          <Share2 className="w-6 h-6 text-white" />
        </Button>

        <Button
          variant="ghost"
          size="icon"
          className="w-12 h-12 rounded-full bg-white/10 backdrop-blur-sm hover:bg-white/20"
          onClick={() => setMuted(!muted)}
          data-testid={`mute-reel-${reel.id}`}
        >
          {muted ? <VolumeX className="w-6 h-6 text-white" /> : <Volume2 className="w-6 h-6 text-white" />}
        </Button>
      </div>

      {/* Bottom info */}
      <div className="absolute left-4 right-20 bottom-8">
        <div className="flex items-center gap-3 mb-3">
          <Avatar className="w-10 h-10 border-2 border-white">
            <AvatarImage src={reel.creator_avatar} />
            <AvatarFallback>{reel.creator_name?.[0]}</AvatarFallback>
          </Avatar>
          <span className="text-white font-medium">{reel.creator_name}</span>
        </div>
        <p className="text-white text-sm line-clamp-2 mb-4">{reel.caption}</p>

        {/* Product tags */}
        {reel.products?.length > 0 && (
          <div className="flex gap-2 overflow-x-auto pb-2 hide-scrollbar">
            {reel.products.map((product) => (
              <div
                key={product.id}
                className="flex-shrink-0 flex items-center gap-2 bg-white/10 backdrop-blur-sm rounded-full pl-1 pr-3 py-1 cursor-pointer"
                onClick={() => navigate(`/shop/${product.id}`)}
              >
                <img 
                  src={product.images?.[0]} 
                  alt={product.title}
                  className="w-8 h-8 rounded-full object-cover"
                />
                <div className="text-white">
                  <p className="text-xs font-medium line-clamp-1 max-w-[100px]">{product.title}</p>
                  <p className="text-xs opacity-80">${product.price?.toFixed(2)}</p>
                </div>
                <Button 
                  size="icon" 
                  className="w-6 h-6 rounded-full bg-white text-black hover:bg-white/90"
                  onClick={(e) => { e.stopPropagation(); handleAddToCart(product.id); }}
                >
                  <ShoppingBag className="w-3 h-3" />
                </Button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export default function ReelsPage() {
  const [searchParams] = useSearchParams();
  const [reels, setReels] = useState([]);
  const [activeIndex, setActiveIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const containerRef = useRef(null);

  useEffect(() => {
    fetchReels();
  }, []);

  useEffect(() => {
    const reelId = searchParams.get('id');
    if (reelId && reels.length > 0) {
      const index = reels.findIndex(r => r.id === reelId);
      if (index !== -1) {
        setActiveIndex(index);
        containerRef.current?.children[index]?.scrollIntoView({ behavior: 'instant' });
      }
    }
  }, [searchParams, reels]);

  const fetchReels = async () => {
    try {
      const response = await axios.get(`${API}/reels`);
      setReels(response.data);
    } catch (err) {
      console.error('Failed to fetch reels:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleLike = async (reelId) => {
    try {
      await axios.post(`${API}/reels/${reelId}/like`);
    } catch {}
  };

  const handleScroll = () => {
    if (!containerRef.current) return;
    const container = containerRef.current;
    const scrollTop = container.scrollTop;
    const itemHeight = container.clientHeight;
    const newIndex = Math.round(scrollTop / itemHeight);
    if (newIndex !== activeIndex) {
      setActiveIndex(newIndex);
    }
  };

  if (loading) {
    return (
      <div className="fixed inset-0 bg-black flex items-center justify-center" data-testid="reels-loading">
        <div className="text-white">Loading reels...</div>
      </div>
    );
  }

  if (reels.length === 0) {
    return (
      <div className="fixed inset-0 bg-black flex items-center justify-center" data-testid="reels-empty">
        <div className="text-white text-center">
          <p className="text-lg mb-2">No reels yet</p>
          <p className="text-sm opacity-60">Check back later!</p>
        </div>
      </div>
    );
  }

  return (
    <div 
      ref={containerRef}
      className="fixed inset-0 lg:left-64 overflow-y-scroll snap-y snap-mandatory hide-scrollbar"
      style={{ paddingTop: '56px', paddingBottom: '64px' }}
      onScroll={handleScroll}
      data-testid="reels-page"
    >
      {reels.map((reel, index) => (
        <div key={reel.id} className="h-[calc(100vh-120px)] lg:h-[calc(100vh-64px)]">
          <ReelCard 
            reel={reel} 
            isActive={index === activeIndex}
            onLike={handleLike}
          />
        </div>
      ))}
    </div>
  );
}