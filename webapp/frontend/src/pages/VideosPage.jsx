import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import axios from 'axios';
import { Play, Eye, Heart, ShoppingBag, ArrowLeft, X } from 'lucide-react';
import { cn } from '../lib/utils';
import { Button } from '../components/ui/button';
import { Card, CardContent } from '../components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '../components/ui/avatar';
import { Skeleton } from '../components/ui/skeleton';
import { Dialog, DialogContent } from '../components/ui/dialog';
import { useCart } from "../contexts/CartContext.jsx";
import { toast } from 'sonner';

const API = `${import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000'}/api`;

function VideoPlayer({ video, onClose }) {
  const { addToCart } = useCart();
  const navigate = useNavigate();

  const handleAddToCart = async (productId) => {
    try {
      await addToCart(productId);
      toast.success('Added to cart!');
    } catch {
      toast.error('Failed to add to cart');
    }
  };

  return (
    <Dialog open={true} onOpenChange={() => onClose()}>
      <DialogContent className="max-w-4xl w-full p-0 overflow-hidden">
        <div className="relative">
          <Button
            variant="ghost"
            size="icon"
            className="absolute top-4 right-4 z-10 bg-black/50 text-white hover:bg-black/70"
            onClick={onClose}
          >
            <X className="w-5 h-5" />
          </Button>
          
          <video
            src={video.url}
            poster={video.thumbnail}
            controls
            autoPlay
            className="w-full aspect-video bg-black"
            data-testid="video-player"
          />
          
          <div className="p-6 bg-card">
            <div className="flex items-start gap-4">
              <Avatar className="w-12 h-12">
                <AvatarImage src={video.creator_avatar} />
                <AvatarFallback>{video.creator_name?.[0]}</AvatarFallback>
              </Avatar>
              <div className="flex-1">
                <h2 className="font-heading text-xl font-bold">{video.title}</h2>
                <p className="text-sm text-muted-foreground">{video.creator_name}</p>
                <div className="flex items-center gap-4 mt-2 text-sm text-muted-foreground">
                  <span className="flex items-center gap-1">
                    <Eye className="w-4 h-4" /> {video.views} views
                  </span>
                  <span className="flex items-center gap-1">
                    <Heart className="w-4 h-4" /> {video.likes} likes
                  </span>
                </div>
                <p className="mt-4 text-muted-foreground">{video.description}</p>
              </div>
            </div>

            {video.products?.length > 0 && (
              <div className="mt-6 pt-6 border-t border-border">
                <h3 className="font-medium mb-4">Featured Products</h3>
                <div className="flex gap-4 overflow-x-auto pb-2">
                  {video.products.map((product) => (
                    <div 
                      key={product.id}
                      className="flex-shrink-0 w-48 cursor-pointer"
                      onClick={() => navigate(`/shop/${product.id}`)}
                    >
                      <div className="aspect-square rounded-lg overflow-hidden bg-muted mb-2">
                        <img 
                          src={product.images?.[0]} 
                          alt={product.title}
                          className="w-full h-full object-cover"
                        />
                      </div>
                      <p className="font-medium text-sm line-clamp-1">{product.title}</p>
                      <p className="text-sm font-bold">${product.price?.toFixed(2)}</p>
                      <Button 
                        size="sm" 
                        className="w-full mt-2 rounded-full"
                        onClick={(e) => { e.stopPropagation(); handleAddToCart(product.id); }}
                      >
                        <ShoppingBag className="w-4 h-4 mr-2" />
                        Add to Cart
                      </Button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

export default function VideosPage() {
  const navigate = useNavigate();
  const { videoId } = useParams();
  const [videos, setVideos] = useState([]);
  const [selectedVideo, setSelectedVideo] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchVideos();
  }, []);

  useEffect(() => {
    if (videoId && videos.length > 0) {
      const video = videos.find(v => v.id === videoId);
      if (video) setSelectedVideo(video);
    }
  }, [videoId, videos]);

  const fetchVideos = async () => {
    try {
      const response = await axios.get(`${API}/videos`);
      setVideos(response.data);
    } catch (err) {
      console.error('Failed to fetch videos:', err);
    } finally {
      setLoading(false);
    }
  };

  const openVideo = async (video) => {
    setSelectedVideo(video);
    navigate(`/videos/${video.id}`);
    // Increment view
    try {
      await axios.get(`${API}/videos/${video.id}`);
    } catch {}
  };

  const closeVideo = () => {
    setSelectedVideo(null);
    navigate('/videos');
  };

  if (loading) {
    return (
      <div data-testid="videos-loading">
        <h1 className="font-heading text-3xl font-bold mb-6">Videos</h1>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {[...Array(4)].map((_, i) => (
            <Skeleton key={i} className="aspect-video rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div data-testid="videos-page">
      <h1 className="font-heading text-3xl font-bold mb-6">Videos</h1>

      {videos.length === 0 ? (
        <div className="flex flex-col items-center justify-center min-h-[50vh] text-center">
          <Play className="w-16 h-16 text-muted-foreground mb-4" />
          <h2 className="text-xl font-heading font-bold mb-2">No videos yet</h2>
          <p className="text-muted-foreground">Check back later for new content!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {videos.map((video, index) => (
            <Card 
              key={video.id}
              className="overflow-hidden group cursor-pointer hover:shadow-lg transition-all animate-fade-in"
              style={{ animationDelay: `${index * 100}ms` }}
              onClick={() => openVideo(video)}
              data-testid={`video-card-${video.id}`}
            >
              <div className="aspect-video relative overflow-hidden bg-muted">
                <img 
                  src={video.thumbnail} 
                  alt={video.title}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                />
                <div className="absolute inset-0 bg-black/30 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                  <div className="w-16 h-16 rounded-full bg-white/90 flex items-center justify-center">
                    <Play className="w-7 h-7 text-black ml-1" fill="currentColor" />
                  </div>
                </div>
                {video.duration > 0 && (
                  <span className="absolute bottom-3 right-3 bg-black/70 text-white text-xs px-2 py-1 rounded">
                    {Math.floor(video.duration / 60)}:{(video.duration % 60).toString().padStart(2, '0')}
                  </span>
                )}
              </div>
              <CardContent className="p-4">
                <div className="flex gap-3">
                  <Avatar className="w-10 h-10">
                    <AvatarImage src={video.creator_avatar} />
                    <AvatarFallback>{video.creator_name?.[0]}</AvatarFallback>
                  </Avatar>
                  <div className="flex-1 min-w-0">
                    <p className="font-medium line-clamp-2">{video.title}</p>
                    <p className="text-sm text-muted-foreground">{video.creator_name}</p>
                    <div className="flex items-center gap-3 mt-1 text-xs text-muted-foreground">
                      <span>{video.views} views</span>
                      <span>{video.likes} likes</span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {selectedVideo && (
        <VideoPlayer video={selectedVideo} onClose={closeVideo} />
      )}
    </div>
  );
}