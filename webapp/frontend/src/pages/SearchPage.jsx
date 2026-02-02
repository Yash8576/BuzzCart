import { useState, useEffect } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import { Search as SearchIcon, X, ShoppingBag, Video, Film, User, Loader2 } from 'lucide-react';
import { cn } from '../lib/utils';
import { Input } from '../components/ui/input';
import { Button } from '../components/ui/button';
import { Card, CardContent } from '../components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { Avatar, AvatarFallback, AvatarImage } from '../components/ui/avatar';
import { useCart } from "../contexts/CartContext.jsx";
import { toast } from 'sonner';

const API = `${import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000'}/api`;

export default function SearchPage() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { addToCart } = useCart();
  const [query, setQuery] = useState(searchParams.get('q') || '');
  const [results, setResults] = useState({ products: [], videos: [], reels: [], users: [] });
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);
  const [activeTab, setActiveTab] = useState('all');

  useEffect(() => {
    const q = searchParams.get('q');
    if (q) {
      setQuery(q);
      performSearch(q);
    }
  }, [searchParams]);

  const performSearch = async (searchQuery) => {
    if (!searchQuery.trim()) return;
    
    setLoading(true);
    setSearched(true);
    try {
      const response = await axios.get(`${API}/search?q=${encodeURIComponent(searchQuery)}`);
      setResults(response.data);
    } catch (err) {
      console.error('Search failed:', err);
      toast.error('Search failed');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = (e) => {
    e.preventDefault();
    if (query.trim()) {
      setSearchParams({ q: query });
      performSearch(query);
    }
  };

  const handleClear = () => {
    setQuery('');
    setSearchParams({});
    setResults({ products: [], videos: [], reels: [], users: [] });
    setSearched(false);
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

  const totalResults = results.products.length + results.videos.length + results.reels.length + results.users.length;

  return (
    <div data-testid="search-page">
      <div className="mb-8">
        <h1 className="font-heading text-3xl font-bold mb-4">Search</h1>
        
        <form onSubmit={handleSearch} className="relative">
          <SearchIcon className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search products, videos, creators..."
            className="pl-12 pr-12 h-12 text-base"
            data-testid="search-input"
          />
          {query && (
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="absolute right-2 top-1/2 -translate-y-1/2"
              onClick={handleClear}
            >
              <X className="w-4 h-4" />
            </Button>
          )}
        </form>
      </div>

      {loading && (
        <div className="flex items-center justify-center py-16">
          <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
        </div>
      )}

      {!loading && searched && totalResults === 0 && (
        <div className="flex flex-col items-center justify-center py-16 text-center" data-testid="no-results">
          <SearchIcon className="w-16 h-16 text-muted-foreground mb-4" />
          <h2 className="text-xl font-heading font-bold mb-2">No results found</h2>
          <p className="text-muted-foreground">Try a different search term</p>
        </div>
      )}

      {!loading && searched && totalResults > 0 && (
        <Tabs value={activeTab} onValueChange={setActiveTab}>
          <TabsList className="mb-6">
            <TabsTrigger value="all">All ({totalResults})</TabsTrigger>
            <TabsTrigger value="products">Products ({results.products.length})</TabsTrigger>
            <TabsTrigger value="videos">Videos ({results.videos.length})</TabsTrigger>
            <TabsTrigger value="reels">Reels ({results.reels.length})</TabsTrigger>
            <TabsTrigger value="users">Users ({results.users.length})</TabsTrigger>
          </TabsList>

          <TabsContent value="all" className="space-y-8">
            {results.products.length > 0 && (
              <div>
                <h3 className="font-heading font-bold text-lg mb-4 flex items-center gap-2">
                  <ShoppingBag className="w-5 h-5" /> Products
                </h3>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  {results.products.slice(0, 4).map((product) => (
                    <Card 
                      key={product.id}
                      className="overflow-hidden cursor-pointer hover:shadow-lg transition-all"
                      onClick={() => navigate(`/shop/${product.id}`)}
                    >
                      <div className="aspect-square bg-muted relative group">
                        <img src={product.images?.[0]} alt={product.title} className="w-full h-full object-cover" />
                        <Button
                          size="icon"
                          className="absolute bottom-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity rounded-full bg-white text-black hover:bg-white/90"
                          onClick={(e) => handleAddToCart(product.id, e)}
                        >
                          <ShoppingBag className="w-4 h-4" />
                        </Button>
                      </div>
                      <CardContent className="p-3">
                        <p className="font-medium line-clamp-1 text-sm">{product.title}</p>
                        <p className="font-bold">${product.price?.toFixed(2)}</p>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              </div>
            )}

            {results.videos.length > 0 && (
              <div>
                <h3 className="font-heading font-bold text-lg mb-4 flex items-center gap-2">
                  <Video className="w-5 h-5" /> Videos
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {results.videos.slice(0, 4).map((video) => (
                    <Card 
                      key={video.id}
                      className="overflow-hidden cursor-pointer hover:shadow-lg transition-all"
                      onClick={() => navigate(`/videos/${video.id}`)}
                    >
                      <div className="aspect-video bg-muted">
                        <img src={video.thumbnail} alt={video.title} className="w-full h-full object-cover" />
                      </div>
                      <CardContent className="p-3">
                        <p className="font-medium line-clamp-1">{video.title}</p>
                        <p className="text-sm text-muted-foreground">{video.creator_name}</p>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              </div>
            )}

            {results.users.length > 0 && (
              <div>
                <h3 className="font-heading font-bold text-lg mb-4 flex items-center gap-2">
                  <User className="w-5 h-5" /> Users
                </h3>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  {results.users.slice(0, 4).map((user) => (
                    <Card 
                      key={user.id}
                      className="p-4 cursor-pointer hover:shadow-lg transition-all text-center"
                      onClick={() => navigate(`/profile/${user.id}`)}
                    >
                      <Avatar className="w-16 h-16 mx-auto mb-3">
                        <AvatarImage src={user.avatar} />
                        <AvatarFallback>{user.name?.[0]}</AvatarFallback>
                      </Avatar>
                      <p className="font-medium">{user.name}</p>
                      <p className="text-sm text-muted-foreground">{user.followers_count} followers</p>
                    </Card>
                  ))}
                </div>
              </div>
            )}
          </TabsContent>

          <TabsContent value="products">
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              {results.products.map((product) => (
                <Card 
                  key={product.id}
                  className="overflow-hidden cursor-pointer hover:shadow-lg transition-all"
                  onClick={() => navigate(`/shop/${product.id}`)}
                >
                  <div className="aspect-square bg-muted relative group">
                    <img src={product.images?.[0]} alt={product.title} className="w-full h-full object-cover" />
                    <Button
                      size="icon"
                      className="absolute bottom-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity rounded-full bg-white text-black hover:bg-white/90"
                      onClick={(e) => handleAddToCart(product.id, e)}
                    >
                      <ShoppingBag className="w-4 h-4" />
                    </Button>
                  </div>
                  <CardContent className="p-3">
                    <p className="font-medium line-clamp-1">{product.title}</p>
                    <p className="font-bold">${product.price?.toFixed(2)}</p>
                  </CardContent>
                </Card>
              ))}
            </div>
          </TabsContent>

          <TabsContent value="videos">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {results.videos.map((video) => (
                <Card 
                  key={video.id}
                  className="overflow-hidden cursor-pointer hover:shadow-lg transition-all"
                  onClick={() => navigate(`/videos/${video.id}`)}
                >
                  <div className="aspect-video bg-muted">
                    <img src={video.thumbnail} alt={video.title} className="w-full h-full object-cover" />
                  </div>
                  <CardContent className="p-4">
                    <p className="font-medium">{video.title}</p>
                    <p className="text-sm text-muted-foreground">{video.creator_name} • {video.views} views</p>
                  </CardContent>
                </Card>
              ))}
            </div>
          </TabsContent>

          <TabsContent value="reels">
            <div className="grid grid-cols-3 md:grid-cols-4 gap-4">
              {results.reels.map((reel) => (
                <div 
                  key={reel.id}
                  className="aspect-[3/4] rounded-lg overflow-hidden cursor-pointer relative group"
                  onClick={() => navigate(`/reels?id=${reel.id}`)}
                >
                  <img src={reel.thumbnail} alt={reel.caption} className="w-full h-full object-cover" />
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <span className="text-white text-sm">{reel.likes} likes</span>
                  </div>
                </div>
              ))}
            </div>
          </TabsContent>

          <TabsContent value="users">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {results.users.map((user) => (
                <Card 
                  key={user.id}
                  className="p-6 cursor-pointer hover:shadow-lg transition-all text-center"
                  onClick={() => navigate(`/profile/${user.id}`)}
                >
                  <Avatar className="w-20 h-20 mx-auto mb-4">
                    <AvatarImage src={user.avatar} />
                    <AvatarFallback>{user.name?.[0]}</AvatarFallback>
                  </Avatar>
                  <p className="font-medium">{user.name}</p>
                  <p className="text-sm text-muted-foreground">{user.followers_count} followers</p>
                </Card>
              ))}
            </div>
          </TabsContent>
        </Tabs>
      )}

      {!loading && !searched && (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <SearchIcon className="w-16 h-16 text-muted-foreground mb-4" />
          <h2 className="text-xl font-heading font-bold mb-2">Find what you're looking for</h2>
          <p className="text-muted-foreground">Search for products, videos, reels, or creators</p>
        </div>
      )}
    </div>
  );
}