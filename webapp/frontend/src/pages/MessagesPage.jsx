import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { Send, ArrowLeft, ShoppingBag, Loader2 } from 'lucide-react';
import { cn } from '../lib/utils';
import { useAuth } from "../contexts/AuthContext.jsx";
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Card } from '../components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '../components/ui/avatar';
import { ScrollArea } from '../components/ui/scroll-area';
import { Skeleton } from '../components/ui/skeleton';

const API = `${import.meta.env.VITE_BACKEND_URL || 'http://localhost:8000'}/api`;

function ConversationList({ conversations, selectedId, onSelect, loading }) {
  if (loading) {
    return (
      <div className="space-y-2">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="flex gap-3 p-3">
            <Skeleton className="w-12 h-12 rounded-full" />
            <div className="flex-1 space-y-2">
              <Skeleton className="h-4 w-24" />
              <Skeleton className="h-3 w-full" />
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (conversations.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-64 text-center p-4">
        <p className="text-muted-foreground">No conversations yet</p>
        <p className="text-sm text-muted-foreground mt-1">Start chatting with sellers!</p>
      </div>
    );
  }

  return (
    <div className="space-y-1">
      {conversations.map((conv) => {
        const otherUser = conv.participants?.[0];
        return (
          <button
            key={conv.id}
            className={cn(
              "w-full flex gap-3 p-3 rounded-lg transition-colors text-left",
              selectedId === conv.id ? "bg-accent" : "hover:bg-accent/50"
            )}
            onClick={() => onSelect(conv)}
            data-testid={`conversation-${conv.id}`}
          >
            <Avatar className="w-12 h-12">
              <AvatarImage src={otherUser?.avatar} />
              <AvatarFallback>{otherUser?.name?.[0]}</AvatarFallback>
            </Avatar>
            <div className="flex-1 min-w-0">
              <p className="font-medium truncate">{otherUser?.name || 'Unknown'}</p>
              <p className="text-sm text-muted-foreground truncate">
                {conv.last_message?.content || 'No messages yet'}
              </p>
            </div>
          </button>
        );
      })}
    </div>
  );
}

function ChatThread({ conversation, onBack }) {
  const { user } = useAuth();
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const scrollRef = useRef(null);

  const otherUser = conversation?.participants?.find(p => p.id !== user?.id) || conversation?.participants?.[0];

  useEffect(() => {
    if (conversation?.id) {
      fetchMessages();
      const interval = setInterval(fetchMessages, 5000); // Poll for new messages
      return () => clearInterval(interval);
    }
  }, [conversation?.id]);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  const fetchMessages = async () => {
    try {
      const response = await axios.get(`${API}/conversations/${conversation.id}/messages`);
      setMessages(response.data);
    } catch (err) {
      console.error('Failed to fetch messages:', err);
    } finally {
      setLoading(false);
    }
  };

  const sendMessage = async () => {
    if (!input.trim() || sending) return;

    const content = input.trim();
    setInput('');
    setSending(true);

    // Optimistic update
    const tempMessage = {
      id: 'temp-' + Date.now(),
      sender_id: user.id,
      content,
      created_at: new Date().toISOString()
    };
    setMessages(prev => [...prev, tempMessage]);

    try {
      await axios.post(`${API}/messages`, {
        receiver_id: otherUser?.id,
        content
      });
      fetchMessages(); // Refresh to get actual message
    } catch (err) {
      console.error('Failed to send message:', err);
      setMessages(prev => prev.filter(m => m.id !== tempMessage.id));
    } finally {
      setSending(false);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-3 p-4 border-b border-border">
        <Button variant="ghost" size="icon" onClick={onBack} className="lg:hidden">
          <ArrowLeft className="w-5 h-5" />
        </Button>
        <Avatar className="w-10 h-10">
          <AvatarImage src={otherUser?.avatar} />
          <AvatarFallback>{otherUser?.name?.[0]}</AvatarFallback>
        </Avatar>
        <div>
          <p className="font-medium">{otherUser?.name}</p>
          <p className="text-xs text-muted-foreground">Active now</p>
        </div>
      </div>

      {/* Messages */}
      <ScrollArea className="flex-1 p-4" ref={scrollRef}>
        {loading ? (
          <div className="flex justify-center py-8">
            <Loader2 className="w-6 h-6 animate-spin text-muted-foreground" />
          </div>
        ) : messages.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-full text-center">
            <p className="text-muted-foreground">No messages yet</p>
            <p className="text-sm text-muted-foreground">Send a message to start the conversation</p>
          </div>
        ) : (
          <div className="space-y-3">
            {messages.map((msg) => {
              const isOwn = msg.sender_id === user?.id;
              return (
                <div
                  key={msg.id}
                  className={cn(
                    "flex",
                    isOwn ? "justify-end" : "justify-start"
                  )}
                >
                  <div className={cn(
                    "max-w-[70%] rounded-2xl px-4 py-2.5",
                    isOwn 
                      ? "bg-primary text-primary-foreground rounded-br-sm" 
                      : "bg-muted rounded-bl-sm"
                  )}>
                    <p className="text-sm whitespace-pre-wrap">{msg.content}</p>
                    <p className={cn(
                      "text-xs mt-1",
                      isOwn ? "text-primary-foreground/70" : "text-muted-foreground"
                    )}>
                      {new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </p>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </ScrollArea>

      {/* Input */}
      <div className="p-4 border-t border-border">
        <div className="flex gap-2">
          <Input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="Type a message..."
            className="flex-1"
            disabled={sending}
            data-testid="message-input"
          />
          <Button 
            onClick={sendMessage} 
            disabled={!input.trim() || sending}
            data-testid="send-message-btn"
          >
            <Send className="w-4 h-4" />
          </Button>
        </div>
      </div>
    </div>
  );
}

export default function MessagesPage() {
  const navigate = useNavigate();
  const [conversations, setConversations] = useState([]);
  const [selectedConversation, setSelectedConversation] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchConversations();
  }, []);

  const fetchConversations = async () => {
    try {
      const response = await axios.get(`${API}/conversations`);
      setConversations(response.data);
    } catch (err) {
      console.error('Failed to fetch conversations:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="h-[calc(100vh-8rem)] lg:h-[calc(100vh-6rem)]" data-testid="messages-page">
      <div className="grid lg:grid-cols-3 h-full gap-4">
        {/* Conversations List */}
        <Card className={cn(
          "lg:col-span-1 overflow-hidden",
          selectedConversation && "hidden lg:block"
        )}>
          <div className="p-4 border-b border-border">
            <h1 className="font-heading text-xl font-bold">Messages</h1>
          </div>
          <ScrollArea className="h-[calc(100%-4rem)]">
            <ConversationList
              conversations={conversations}
              selectedId={selectedConversation?.id}
              onSelect={setSelectedConversation}
              loading={loading}
            />
          </ScrollArea>
        </Card>

        {/* Chat Thread */}
        <Card className={cn(
          "lg:col-span-2 overflow-hidden",
          !selectedConversation && "hidden lg:flex lg:items-center lg:justify-center"
        )}>
          {selectedConversation ? (
            <ChatThread 
              conversation={selectedConversation} 
              onBack={() => setSelectedConversation(null)}
            />
          ) : (
            <div className="text-center p-8">
              <p className="text-muted-foreground">Select a conversation to start messaging</p>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}