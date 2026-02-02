import { useState } from 'react';
import { Outlet, NavLink, useLocation, useNavigate } from 'react-router-dom';
import { Home, Video, Film, ShoppingBag, User, Search, MessageCircle, Settings, ShoppingCart, Menu, X, Bot, LogOut } from 'lucide-react';
import { cn } from '../../lib/utils';
import { useAuth } from "../../contexts/AuthContext.jsx";
import { useCart } from "../../contexts/CartContext.jsx";
import { Button } from '../ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '../ui/avatar';
import { Sheet, SheetContent, SheetTrigger } from '../ui/sheet';
import ChatBot from '../chat/ChatBot';

const navItems = [
  { path: '/', icon: Home, label: 'Home' },
  { path: '/videos', icon: Video, label: 'Videos' },
  { path: '/reels', icon: Film, label: 'Reels' },
  { path: '/shop', icon: ShoppingBag, label: 'Shop' },
  { path: '/profile', icon: User, label: 'Profile' },
];

const sidebarOnlyItems = [
  { path: '/search', icon: Search, label: 'Search' },
  { path: '/messages', icon: MessageCircle, label: 'Messages' },
  { path: '/settings', icon: Settings, label: 'Settings' },
];

export default function MainLayout() {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const { cart } = useCart();
  const [chatOpen, setChatOpen] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen bg-background">
      {/* Desktop Sidebar */}
      <aside className="hidden lg:flex fixed left-0 top-0 h-full w-64 flex-col border-r border-border bg-card z-40">
        {/* Logo */}
        <div className="p-6 border-b border-border">
          <h1 className="font-heading text-2xl font-bold tracking-tight">
            Buzz<span className="text-electric-blue">Cart</span>
          </h1>
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
          {navItems.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              data-testid={`nav-${item.label.toLowerCase()}`}
              className={({ isActive }) => cn(
                "flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all",
                isActive 
                  ? "bg-primary text-primary-foreground shadow-lg" 
                  : "text-muted-foreground hover:bg-accent hover:text-foreground"
              )}
            >
              <item.icon className="w-5 h-5" />
              {item.label}
            </NavLink>
          ))}

          <div className="pt-4 border-t border-border mt-4">
            {sidebarOnlyItems.map((item) => (
              <NavLink
                key={item.path}
                to={item.path}
                data-testid={`nav-${item.label.toLowerCase()}`}
                className={({ isActive }) => cn(
                  "flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all",
                  isActive 
                    ? "bg-primary text-primary-foreground shadow-lg" 
                    : "text-muted-foreground hover:bg-accent hover:text-foreground"
                )}
              >
                <item.icon className="w-5 h-5" />
                {item.label}
              </NavLink>
            ))}
          </div>
        </nav>

        {/* User Profile */}
        <div className="p-4 border-t border-border">
          <div className="flex items-center gap-3 p-3 rounded-xl bg-accent/50">
            <Avatar className="w-10 h-10">
              <AvatarImage src={user?.avatar} alt={user?.name} />
              <AvatarFallback>{user?.name?.[0]?.toUpperCase() || 'U'}</AvatarFallback>
            </Avatar>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{user?.name}</p>
              <p className="text-xs text-muted-foreground truncate">{user?.email}</p>
            </div>
            <Button variant="ghost" size="icon" onClick={handleLogout} data-testid="logout-btn">
              <LogOut className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </aside>

      {/* Mobile Header */}
      <header className="lg:hidden fixed top-0 left-0 right-0 h-14 glass z-40 flex items-center justify-between px-4">
        <h1 className="font-heading text-xl font-bold">
          Buzz<span className="text-electric-blue">Cart</span>
        </h1>
        
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="icon" onClick={() => navigate('/search')} data-testid="mobile-search-btn">
            <Search className="w-5 h-5" />
          </Button>
          <Button variant="ghost" size="icon" onClick={() => navigate('/cart')} className="relative" data-testid="mobile-cart-btn">
            <ShoppingCart className="w-5 h-5" />
            {cart.item_count > 0 && (
              <span className="absolute -top-1 -right-1 w-5 h-5 bg-electric-blue text-white text-xs rounded-full flex items-center justify-center">
                {cart.item_count}
              </span>
            )}
          </Button>
          <Sheet open={mobileMenuOpen} onOpenChange={setMobileMenuOpen}>
            <SheetTrigger asChild>
              <Button variant="ghost" size="icon" data-testid="mobile-menu-btn">
                <Menu className="w-5 h-5" />
              </Button>
            </SheetTrigger>
            <SheetContent side="right" className="w-72">
              <div className="flex flex-col h-full">
                <div className="flex items-center gap-3 p-4 border-b border-border">
                  <Avatar>
                    <AvatarImage src={user?.avatar} alt={user?.name} />
                    <AvatarFallback>{user?.name?.[0]?.toUpperCase() || 'U'}</AvatarFallback>
                  </Avatar>
                  <div>
                    <p className="font-medium">{user?.name}</p>
                    <p className="text-sm text-muted-foreground">{user?.email}</p>
                  </div>
                </div>
                <nav className="flex-1 p-4 space-y-1">
                  {[...sidebarOnlyItems].map((item) => (
                    <Button
                      key={item.path}
                      variant="ghost"
                      className="w-full justify-start gap-3"
                      onClick={() => { navigate(item.path); setMobileMenuOpen(false); }}
                    >
                      <item.icon className="w-5 h-5" />
                      {item.label}
                    </Button>
                  ))}
                </nav>
                <div className="p-4 border-t border-border">
                  <Button variant="outline" className="w-full gap-2" onClick={handleLogout}>
                    <LogOut className="w-4 h-4" />
                    Log Out
                  </Button>
                </div>
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </header>

      {/* Desktop Top Bar */}
      <header className="hidden lg:flex fixed top-0 left-64 right-0 h-16 glass z-30 items-center justify-between px-8">
        <div className="flex items-center gap-4">
          <Button 
            variant="outline" 
            className="gap-2 px-4"
            onClick={() => navigate('/search')}
            data-testid="desktop-search-btn"
          >
            <Search className="w-4 h-4" />
            Search products, videos...
          </Button>
        </div>
        <div className="flex items-center gap-3">
          <Button 
            variant="ghost" 
            size="icon" 
            className="relative"
            onClick={() => navigate('/cart')}
            data-testid="desktop-cart-btn"
          >
            <ShoppingCart className="w-5 h-5" />
            {cart.item_count > 0 && (
              <span className="absolute -top-1 -right-1 w-5 h-5 bg-electric-blue text-white text-xs rounded-full flex items-center justify-center">
                {cart.item_count}
              </span>
            )}
          </Button>
        </div>
      </header>

      {/* Main Content */}
      <main className="lg:ml-64 pt-14 lg:pt-16 pb-20 lg:pb-8 min-h-screen">
        <div className="p-4 lg:p-8">
          <Outlet />
        </div>
      </main>

      {/* Mobile Bottom Navigation */}
      <nav className="lg:hidden fixed bottom-0 left-0 right-0 h-16 glass z-40 flex items-center justify-around px-2 pb-safe">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path || 
            (item.path !== '/' && location.pathname.startsWith(item.path));
          return (
            <NavLink
              key={item.path}
              to={item.path}
              data-testid={`mobile-nav-${item.label.toLowerCase()}`}
              className={cn(
                "flex flex-col items-center gap-1 px-3 py-2 rounded-xl transition-all",
                isActive 
                  ? "text-electric-blue" 
                  : "text-muted-foreground"
              )}
            >
              <item.icon className={cn("w-5 h-5", isActive && "scale-110")} />
              <span className="text-xs font-medium">{item.label}</span>
            </NavLink>
          );
        })}
      </nav>

      {/* Floating Chat Button */}
      <Button
        onClick={() => setChatOpen(true)}
        className="fixed bottom-20 lg:bottom-8 right-4 lg:right-8 w-14 h-14 rounded-full shadow-xl bg-electric-blue hover:bg-electric-blue/90 z-30"
        data-testid="chat-btn"
      >
        <Bot className="w-6 h-6 text-white" />
      </Button>

      {/* Chat Modal */}
      <ChatBot open={chatOpen} onClose={() => setChatOpen(false)} />
    </div>
  );
}