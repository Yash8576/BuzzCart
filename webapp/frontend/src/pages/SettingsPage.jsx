import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Moon, Sun, Monitor, Bell, Lock, Eye, Shield, Info, LogOut, ChevronRight, User } from 'lucide-react';
import { cn } from '../lib/utils';
import { useTheme } from "../contexts/ThemeContext.jsx";
import { useAuth } from "../contexts/AuthContext.jsx";
import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Switch } from '../components/ui/switch';
import { Label } from '../components/ui/label';
import { Separator } from '../components/ui/separator';
import { toast } from 'sonner';

export default function SettingsPage() {
  const navigate = useNavigate();
  const { theme, toggleTheme, setLightTheme, setDarkTheme, setSystemTheme } = useTheme();
  const { logout, user } = useAuth();
  const [notifications, setNotifications] = useState({
    push: true,
    email: true,
    messages: true,
    orders: true
  });
  const [privacy, setPrivacy] = useState({
    publicProfile: true,
    showActivity: true
  });

  const handleLogout = () => {
    logout();
    toast.success('Logged out successfully');
    navigate('/login');
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6" data-testid="settings-page">
      <h1 className="font-heading text-3xl font-bold">Settings</h1>

      {/* Appearance */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Sun className="w-5 h-5" />
            Appearance
          </CardTitle>
          <CardDescription>Customize how Buzz looks on your device</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-3 gap-3">
            <Button
              variant={theme === 'light' ? 'default' : 'outline'}
              className="flex-col h-auto py-4 gap-2"
              onClick={setLightTheme}
              data-testid="theme-light-btn"
            >
              <Sun className="w-6 h-6" />
              <span className="text-sm">Light</span>
            </Button>
            <Button
              variant={theme === 'dark' ? 'default' : 'outline'}
              className="flex-col h-auto py-4 gap-2"
              onClick={setDarkTheme}
              data-testid="theme-dark-btn"
            >
              <Moon className="w-6 h-6" />
              <span className="text-sm">Dark</span>
            </Button>
            <Button
              variant="outline"
              className="flex-col h-auto py-4 gap-2"
              onClick={setSystemTheme}
              data-testid="theme-system-btn"
            >
              <Monitor className="w-6 h-6" />
              <span className="text-sm">System</span>
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Notifications */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Bell className="w-5 h-5" />
            Notifications
          </CardTitle>
          <CardDescription>Manage how you receive notifications</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <Label htmlFor="push">Push Notifications</Label>
              <p className="text-sm text-muted-foreground">Receive push notifications</p>
            </div>
            <Switch
              id="push"
              checked={notifications.push}
              onCheckedChange={(checked) => setNotifications(prev => ({ ...prev, push: checked }))}
            />
          </div>
          <Separator />
          <div className="flex items-center justify-between">
            <div>
              <Label htmlFor="email-notif">Email Notifications</Label>
              <p className="text-sm text-muted-foreground">Receive email updates</p>
            </div>
            <Switch
              id="email-notif"
              checked={notifications.email}
              onCheckedChange={(checked) => setNotifications(prev => ({ ...prev, email: checked }))}
            />
          </div>
          <Separator />
          <div className="flex items-center justify-between">
            <div>
              <Label htmlFor="messages-notif">Message Notifications</Label>
              <p className="text-sm text-muted-foreground">Get notified about new messages</p>
            </div>
            <Switch
              id="messages-notif"
              checked={notifications.messages}
              onCheckedChange={(checked) => setNotifications(prev => ({ ...prev, messages: checked }))}
            />
          </div>
          <Separator />
          <div className="flex items-center justify-between">
            <div>
              <Label htmlFor="orders-notif">Order Updates</Label>
              <p className="text-sm text-muted-foreground">Get notified about order status</p>
            </div>
            <Switch
              id="orders-notif"
              checked={notifications.orders}
              onCheckedChange={(checked) => setNotifications(prev => ({ ...prev, orders: checked }))}
            />
          </div>
        </CardContent>
      </Card>

      {/* Privacy */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Shield className="w-5 h-5" />
            Privacy
          </CardTitle>
          <CardDescription>Control your privacy settings</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <Label htmlFor="public-profile">Public Profile</Label>
              <p className="text-sm text-muted-foreground">Allow others to see your profile</p>
            </div>
            <Switch
              id="public-profile"
              checked={privacy.publicProfile}
              onCheckedChange={(checked) => setPrivacy(prev => ({ ...prev, publicProfile: checked }))}
            />
          </div>
          <Separator />
          <div className="flex items-center justify-between">
            <div>
              <Label htmlFor="show-activity">Show Activity Status</Label>
              <p className="text-sm text-muted-foreground">Show when you're online</p>
            </div>
            <Switch
              id="show-activity"
              checked={privacy.showActivity}
              onCheckedChange={(checked) => setPrivacy(prev => ({ ...prev, showActivity: checked }))}
            />
          </div>
        </CardContent>
      </Card>

      {/* Account */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <User className="w-5 h-5" />
            Account
          </CardTitle>
          <CardDescription>Manage your account settings</CardDescription>
        </CardHeader>
        <CardContent className="space-y-2">
          <Button variant="ghost" className="w-full justify-between" onClick={() => navigate('/profile')}>
            <span className="flex items-center gap-2">
              <Eye className="w-4 h-4" />
              View Profile
            </span>
            <ChevronRight className="w-4 h-4" />
          </Button>
          <Button variant="ghost" className="w-full justify-between">
            <span className="flex items-center gap-2">
              <Lock className="w-4 h-4" />
              Change Password
            </span>
            <ChevronRight className="w-4 h-4" />
          </Button>
          <Button variant="ghost" className="w-full justify-between">
            <span className="flex items-center gap-2">
              <Shield className="w-4 h-4" />
              Blocked Users
            </span>
            <ChevronRight className="w-4 h-4" />
          </Button>
        </CardContent>
      </Card>

      {/* About */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Info className="w-5 h-5" />
            About
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          <div className="flex justify-between py-2">
            <span className="text-muted-foreground">Version</span>
            <span>1.0.0</span>
          </div>
          <Separator />
          <Button variant="ghost" className="w-full justify-between">
            <span>Terms of Service</span>
            <ChevronRight className="w-4 h-4" />
          </Button>
          <Button variant="ghost" className="w-full justify-between">
            <span>Privacy Policy</span>
            <ChevronRight className="w-4 h-4" />
          </Button>
        </CardContent>
      </Card>

      {/* Logout */}
      <Card className="border-destructive/50">
        <CardContent className="pt-6">
          <Button 
            variant="destructive" 
            className="w-full gap-2"
            onClick={handleLogout}
            data-testid="logout-btn"
          >
            <LogOut className="w-4 h-4" />
            Log Out
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}