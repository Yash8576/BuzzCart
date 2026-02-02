import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { Edit2, Grid, Film, ShoppingBag, Settings, Users, Share2, Camera } from 'lucide-react';
import { cn } from '../lib/utils';
import { useAuth } from "../contexts/AuthContext.jsx";
import { Button } from '../components/ui/button';
import { Card, CardContent } from '../components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '../components/ui/avatar';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../components/ui/tabs';
import { Skeleton } from '../components/ui/skeleton';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '../components/ui/dialog';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { Textarea } from '../components/ui/textarea';
import { toast } from 'sonner';

const API = `${import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000'}/api`;

function EditProfileDialog({ user, onUpdate }) {
  const [name, setName] = useState(user?.name || '');
  const [bio, setBio] = useState(user?.bio || '');
  const [avatar, setAvatar] = useState(user?.avatar || '');
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await onUpdate({ name, bio, avatar });
      toast.success('Profile updated!');
      setOpen(false);
    } catch {
      toast.error('Failed to update profile');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" className="gap-2 rounded-full" data-testid="edit-profile-btn">
          <Edit2 className="w-4 h-4" />
          Edit Profile
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Edit Profile</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="name">Name</Label>
            <Input
              id="name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Your name"
              data-testid="edit-name-input"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="bio">Bio</Label>
            <Textarea
              id="bio"
              value={bio}
              onChange={(e) => setBio(e.target.value)}
              placeholder="Tell us about yourself"
              rows={3}
              data-testid="edit-bio-input"
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="avatar">Avatar URL</Label>
            <Input
              id="avatar"
              value={avatar}
              onChange={(e) => setAvatar(e.target.value)}
              placeholder="https://..."
              data-testid="edit-avatar-input"
            />
          </div>
          <Button type="submit" className="w-full rounded-full" disabled={loading} data-testid="save-profile-btn">
            {loading ? 'Saving...' : 'Save Changes'}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}

export default function ProfilePage() {
  const navigate = useNavigate();
  const { user, updateProfile } = useAuth();
  const [videos, setVideos] = useState([]);
  const [reels, setReels] = useState([]);
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('posts');

  useEffect(() => {
    if (user?.id) {
      fetchUserContent();
    }
  }, [user?.id]);

  const fetchUserContent = async () => {
    try {
      setLoading(true);
      const [videosRes, reelsRes, productsRes] = await Promise.all([
        axios.get(`${API}/videos`),
        axios.get(`${API}/reels`),
        axios.get(`${API}/products/seller/${user.id}`)
      ]);
      
      // Filter by creator
      setVideos(videosRes.data.filter(v => v.creator_id === user.id));
      setReels(reelsRes.data.filter(r => r.creator_id === user.id));
      setProducts(productsRes.data);
    } catch (err) {
      console.error('Failed to fetch content:', err);
    } finally {
      setLoading(false);
    }
  };

  if (!user) {
    return (
      <div className="flex items-center justify-center min-h-[50vh]">
        <p className="text-muted-foreground">Please log in to view your profile.</p>
      </div>
    );
  }

  return (
    <div data-testid="profile-page">
      {/* Profile Header */}
      <div className="relative mb-8">
        {/* Cover */}
        <div className="h-32 md:h-48 rounded-2xl bg-gradient-to-br from-electric-blue/20 to-neon-purple/20" />
        
        {/* Profile Info */}
        <div className="flex flex-col md:flex-row items-start md:items-end gap-4 -mt-16 md:-mt-12 px-4">
          <Avatar className="w-28 h-28 border-4 border-background shadow-xl">
            <AvatarImage src={user.avatar} alt={user.name} />
            <AvatarFallback className="text-3xl">{user.name?.[0]?.toUpperCase()}</AvatarFallback>
          </Avatar>
          
          <div className="flex-1">
            <h1 className="font-heading text-2xl font-bold">{user.name}</h1>
            <p className="text-muted-foreground">{user.email}</p>
            {user.bio && <p className="mt-2 text-sm">{user.bio}</p>}
          </div>

          <div className="flex gap-3 mt-4 md:mt-0">
            <EditProfileDialog user={user} onUpdate={updateProfile} />
            <Button variant="outline" size="icon" className="rounded-full" onClick={() => navigate('/settings')}>
              <Settings className="w-4 h-4" />
            </Button>
            <Button variant="outline" size="icon" className="rounded-full">
              <Share2 className="w-4 h-4" />
            </Button>
          </div>
        </div>

        {/* Stats */}
        <div className="flex gap-8 mt-6 px-4">
          <div className="text-center">
            <p className="font-heading text-2xl font-bold">{videos.length + reels.length}</p>
            <p className="text-sm text-muted-foreground">Posts</p>
          </div>
          <div className="text-center">
            <p className="font-heading text-2xl font-bold">{user.followers_count || 0}</p>
            <p className="text-sm text-muted-foreground">Followers</p>
          </div>
          <div className="text-center">
            <p className="font-heading text-2xl font-bold">{user.following_count || 0}</p>
            <p className="text-sm text-muted-foreground">Following</p>
          </div>
        </div>
      </div>

      {/* Content Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="w-full justify-start border-b border-border rounded-none bg-transparent h-auto p-0">
          <TabsTrigger 
            value="posts" 
            className="rounded-none border-b-2 border-transparent data-[state=active]:border-primary data-[state=active]:bg-transparent"
          >
            <Grid className="w-4 h-4 mr-2" />
            Posts
          </TabsTrigger>
          <TabsTrigger 
            value="reels"
            className="rounded-none border-b-2 border-transparent data-[state=active]:border-primary data-[state=active]:bg-transparent"
          >
            <Film className="w-4 h-4 mr-2" />
            Reels
          </TabsTrigger>
          <TabsTrigger 
            value="shop"
            className="rounded-none border-b-2 border-transparent data-[state=active]:border-primary data-[state=active]:bg-transparent"
          >
            <ShoppingBag className="w-4 h-4 mr-2" />
            Shop
          </TabsTrigger>
        </TabsList>

        <TabsContent value="posts" className="mt-6">
          {loading ? (
            <div className="grid grid-cols-3 gap-1 md:gap-4">
              {[...Array(6)].map((_, i) => (
                <Skeleton key={i} className="aspect-square rounded-lg" />
              ))}
            </div>
          ) : videos.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-center">
              <Camera className="w-12 h-12 text-muted-foreground mb-4" />
              <p className="text-muted-foreground">No posts yet</p>
            </div>
          ) : (
            <div className="grid grid-cols-3 gap-1 md:gap-4">
              {videos.map((video) => (
                <div 
                  key={video.id}
                  className="aspect-square rounded-lg overflow-hidden cursor-pointer relative group"
                  onClick={() => navigate(`/videos/${video.id}`)}
                >
                  <img 
                    src={video.thumbnail} 
                    alt={video.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                  />
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <span className="text-white text-sm">{video.views} views</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </TabsContent>

        <TabsContent value="reels" className="mt-6">
          {loading ? (
            <div className="grid grid-cols-3 gap-1 md:gap-4">
              {[...Array(6)].map((_, i) => (
                <Skeleton key={i} className="aspect-[3/4] rounded-lg" />
              ))}
            </div>
          ) : reels.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-center">
              <Film className="w-12 h-12 text-muted-foreground mb-4" />
              <p className="text-muted-foreground">No reels yet</p>
            </div>
          ) : (
            <div className="grid grid-cols-3 gap-1 md:gap-4">
              {reels.map((reel) => (
                <div 
                  key={reel.id}
                  className="aspect-[3/4] rounded-lg overflow-hidden cursor-pointer relative group"
                  onClick={() => navigate(`/reels?id=${reel.id}`)}
                >
                  <img 
                    src={reel.thumbnail} 
                    alt={reel.caption}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                  />
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <span className="text-white text-sm">{reel.likes} likes</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </TabsContent>

        <TabsContent value="shop" className="mt-6">
          {loading ? (
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
              {[...Array(6)].map((_, i) => (
                <Skeleton key={i} className="aspect-square rounded-xl" />
              ))}
            </div>
          ) : products.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-center">
              <ShoppingBag className="w-12 h-12 text-muted-foreground mb-4" />
              <p className="text-muted-foreground">No products listed yet</p>
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
              {products.map((product) => (
                <Card 
                  key={product.id}
                  className="overflow-hidden cursor-pointer hover:shadow-lg transition-all"
                  onClick={() => navigate(`/shop/${product.id}`)}
                >
                  <div className="aspect-square bg-muted">
                    <img 
                      src={product.images?.[0]} 
                      alt={product.title}
                      className="w-full h-full object-cover"
                    />
                  </div>
                  <CardContent className="p-3">
                    <p className="font-medium line-clamp-1">{product.title}</p>
                    <p className="font-bold">${product.price?.toFixed(2)}</p>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
}