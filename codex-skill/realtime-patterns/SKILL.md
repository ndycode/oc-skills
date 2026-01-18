---
name: realtime-patterns
description: Real-time patterns with WebSockets, SSE, and Supabase
metadata:
  short-description: Real-time patterns
---

# Real-Time Patterns

> **Sources**: [supabase/realtime](https://github.com/supabase/realtime) (6.8k⭐), [socketio/socket.io](https://github.com/socketio/socket.io) (61k⭐), [MDN EventSource](https://developer.mozilla.org/en-US/docs/Web/API/EventSource)
> **Auto-trigger**: Files containing `WebSocket`, `socket.io`, `EventSource`, `SSE`, `realtime`, `supabase`, `presence`, `broadcast`

---

## Technology Selection

| Use Case | Technology | When to Use |
|----------|------------|-------------|
| **Server-Sent Events (SSE)** | Native EventSource | One-way server→client, simple updates |
| **WebSocket** | ws / Socket.IO | Bidirectional, low latency, custom protocols |
| **Supabase Realtime** | @supabase/supabase-js | Postgres changes, presence, broadcast |
| **Pusher/Ably** | Managed service | Scale without infrastructure |

---

## Server-Sent Events (SSE)

### Server (Next.js Route Handler)
```typescript
// app/api/events/route.ts
import { NextRequest } from 'next/server';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      // Send initial connection message
      controller.enqueue(
        encoder.encode(`data: ${JSON.stringify({ type: 'connected' })}\n\n`)
      );

      // Example: Send updates every 5 seconds
      const interval = setInterval(() => {
        const data = {
          type: 'update',
          timestamp: new Date().toISOString(),
          value: Math.random(),
        };
        controller.enqueue(
          encoder.encode(`data: ${JSON.stringify(data)}\n\n`)
        );
      }, 5000);

      // Cleanup on client disconnect
      req.signal.addEventListener('abort', () => {
        clearInterval(interval);
        controller.close();
      });
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no', // Disable Nginx buffering
    },
  });
}
```

### Client Hook
```typescript
// hooks/useSSE.ts
'use client';

import { useEffect, useState, useCallback } from 'react';

interface SSEOptions<T> {
  onMessage?: (data: T) => void;
  onError?: (error: Event) => void;
  reconnectInterval?: number;
}

export function useSSE<T>(url: string, options: SSEOptions<T> = {}) {
  const [data, setData] = useState<T | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const { onMessage, onError, reconnectInterval = 3000 } = options;

  useEffect(() => {
    let eventSource: EventSource;
    let reconnectTimeout: NodeJS.Timeout;

    const connect = () => {
      eventSource = new EventSource(url);

      eventSource.onopen = () => {
        setIsConnected(true);
        setError(null);
      };

      eventSource.onmessage = (event) => {
        try {
          const parsed = JSON.parse(event.data) as T;
          setData(parsed);
          onMessage?.(parsed);
        } catch (e) {
          console.error('Failed to parse SSE data:', e);
        }
      };

      eventSource.onerror = (event) => {
        setIsConnected(false);
        setError(new Error('SSE connection failed'));
        onError?.(event);

        // Reconnect
        eventSource.close();
        reconnectTimeout = setTimeout(connect, reconnectInterval);
      };
    };

    connect();

    return () => {
      eventSource?.close();
      clearTimeout(reconnectTimeout);
    };
  }, [url, onMessage, onError, reconnectInterval]);

  return { data, isConnected, error };
}

// Usage
function LiveUpdates() {
  const { data, isConnected } = useSSE<{ value: number }>('/api/events');

  return (
    <div>
      <span>{isConnected ? '🟢' : '🔴'}</span>
      <span>Value: {data?.value}</span>
    </div>
  );
}
```

### SSE with Event Types
```typescript
// Server: Named events
controller.enqueue(
  encoder.encode(`event: notification\ndata: ${JSON.stringify(data)}\n\n`)
);
controller.enqueue(
  encoder.encode(`event: status\ndata: ${JSON.stringify(status)}\n\n`)
);

// Client: Listen to specific events
eventSource.addEventListener('notification', (event) => {
  console.log('Notification:', JSON.parse(event.data));
});

eventSource.addEventListener('status', (event) => {
  console.log('Status:', JSON.parse(event.data));
});
```

---

## WebSocket (Native)

### Server (Node.js with ws)
```typescript
// server/websocket.ts
import { WebSocketServer, WebSocket } from 'ws';
import { createServer } from 'http';

const server = createServer();
const wss = new WebSocketServer({ server });

// Connection registry
const clients = new Map<string, WebSocket>();

wss.on('connection', (ws, req) => {
  const clientId = crypto.randomUUID();
  clients.set(clientId, ws);

  console.log(`Client connected: ${clientId}`);

  // Send welcome message
  ws.send(JSON.stringify({
    type: 'connected',
    clientId,
  }));

  ws.on('message', (data) => {
    try {
      const message = JSON.parse(data.toString());
      handleMessage(clientId, message);
    } catch (e) {
      console.error('Invalid message:', e);
    }
  });

  ws.on('close', () => {
    clients.delete(clientId);
    console.log(`Client disconnected: ${clientId}`);
  });

  ws.on('error', (error) => {
    console.error(`WebSocket error for ${clientId}:`, error);
    clients.delete(clientId);
  });

  // Heartbeat
  ws.on('pong', () => {
    // Client is alive
  });
});

// Heartbeat interval
setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.ping();
    }
  });
}, 30000);

function handleMessage(clientId: string, message: any) {
  switch (message.type) {
    case 'broadcast':
      broadcast(message.data, clientId);
      break;
    case 'direct':
      sendTo(message.targetId, message.data);
      break;
  }
}

function broadcast(data: any, excludeId?: string) {
  const payload = JSON.stringify({ type: 'broadcast', data });
  clients.forEach((ws, id) => {
    if (id !== excludeId && ws.readyState === WebSocket.OPEN) {
      ws.send(payload);
    }
  });
}

function sendTo(clientId: string, data: any) {
  const ws = clients.get(clientId);
  if (ws?.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'direct', data }));
  }
}

server.listen(8080);
```

### Client Hook
```typescript
// hooks/useWebSocket.ts
'use client';

import { useEffect, useRef, useState, useCallback } from 'react';

interface WebSocketOptions {
  onOpen?: () => void;
  onClose?: () => void;
  onError?: (error: Event) => void;
  reconnect?: boolean;
  reconnectInterval?: number;
  maxReconnectAttempts?: number;
}

export function useWebSocket(url: string, options: WebSocketOptions = {}) {
  const [isConnected, setIsConnected] = useState(false);
  const [lastMessage, setLastMessage] = useState<any>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectCount = useRef(0);

  const {
    onOpen,
    onClose,
    onError,
    reconnect = true,
    reconnectInterval = 3000,
    maxReconnectAttempts = 5,
  } = options;

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      setIsConnected(true);
      reconnectCount.current = 0;
      onOpen?.();
    };

    ws.onclose = () => {
      setIsConnected(false);
      onClose?.();

      if (reconnect && reconnectCount.current < maxReconnectAttempts) {
        reconnectCount.current++;
        setTimeout(connect, reconnectInterval);
      }
    };

    ws.onerror = (error) => {
      onError?.(error);
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        setLastMessage(data);
      } catch {
        setLastMessage(event.data);
      }
    };
  }, [url, onOpen, onClose, onError, reconnect, reconnectInterval, maxReconnectAttempts]);

  const send = useCallback((data: any) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(data));
    }
  }, []);

  const disconnect = useCallback(() => {
    wsRef.current?.close();
  }, []);

  useEffect(() => {
    connect();
    return () => {
      wsRef.current?.close();
    };
  }, [connect]);

  return { isConnected, lastMessage, send, disconnect };
}
```

---

## Socket.IO (Full-Featured)

### Server
```typescript
// server/socket-io.ts
import { Server } from 'socket.io';
import { createServer } from 'http';
import { verifyToken } from './auth';

const httpServer = createServer();
const io = new Server(httpServer, {
  cors: {
    origin: process.env.CLIENT_URL,
    credentials: true,
  },
  pingTimeout: 60000,
  pingInterval: 25000,
});

// Authentication middleware
io.use(async (socket, next) => {
  const token = socket.handshake.auth.token;
  try {
    const user = await verifyToken(token);
    socket.data.user = user;
    next();
  } catch (err) {
    next(new Error('Authentication failed'));
  }
});

io.on('connection', (socket) => {
  const userId = socket.data.user.id;
  console.log(`User connected: ${userId}`);

  // Join user's personal room
  socket.join(`user:${userId}`);

  // Join a channel
  socket.on('join:channel', (channelId: string) => {
    socket.join(`channel:${channelId}`);
    socket.to(`channel:${channelId}`).emit('user:joined', {
      userId,
      channelId,
    });
  });

  // Leave a channel
  socket.on('leave:channel', (channelId: string) => {
    socket.leave(`channel:${channelId}`);
    socket.to(`channel:${channelId}`).emit('user:left', {
      userId,
      channelId,
    });
  });

  // Send message to channel
  socket.on('message:send', async (data: { channelId: string; content: string }) => {
    const message = {
      id: crypto.randomUUID(),
      userId,
      content: data.content,
      createdAt: new Date().toISOString(),
    };

    // Broadcast to channel (including sender)
    io.to(`channel:${data.channelId}`).emit('message:new', message);
  });

  // Typing indicator
  socket.on('typing:start', (channelId: string) => {
    socket.to(`channel:${channelId}`).emit('typing:update', {
      userId,
      isTyping: true,
    });
  });

  socket.on('typing:stop', (channelId: string) => {
    socket.to(`channel:${channelId}`).emit('typing:update', {
      userId,
      isTyping: false,
    });
  });

  socket.on('disconnect', () => {
    console.log(`User disconnected: ${userId}`);
  });
});

httpServer.listen(3001);
```

### Client
```typescript
// lib/socket.ts
import { io, Socket } from 'socket.io-client';

let socket: Socket | null = null;

export function getSocket(token: string): Socket {
  if (!socket) {
    socket = io(process.env.NEXT_PUBLIC_SOCKET_URL!, {
      auth: { token },
      autoConnect: false,
      reconnection: true,
      reconnectionAttempts: 5,
      reconnectionDelay: 1000,
    });
  }
  return socket;
}

export function disconnectSocket() {
  socket?.disconnect();
  socket = null;
}
```

```typescript
// hooks/useSocket.ts
'use client';

import { useEffect, useState } from 'react';
import { getSocket, disconnectSocket } from '@/lib/socket';
import { useSession } from 'next-auth/react';

export function useSocket() {
  const { data: session } = useSession();
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    if (!session?.accessToken) return;

    const socket = getSocket(session.accessToken);

    socket.on('connect', () => setIsConnected(true));
    socket.on('disconnect', () => setIsConnected(false));

    socket.connect();

    return () => {
      disconnectSocket();
    };
  }, [session?.accessToken]);

  return { isConnected, socket: session?.accessToken ? getSocket(session.accessToken) : null };
}
```

---

## Supabase Realtime

### Database Changes
```typescript
// hooks/useRealtimeMessages.ts
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import type { Message } from '@/types';

export function useRealtimeMessages(channelId: string) {
  const [messages, setMessages] = useState<Message[]>([]);
  const supabase = createClient();

  useEffect(() => {
    // Initial fetch
    supabase
      .from('messages')
      .select('*')
      .eq('channel_id', channelId)
      .order('created_at', { ascending: true })
      .then(({ data }) => {
        if (data) setMessages(data);
      });

    // Subscribe to changes
    const channel = supabase
      .channel(`messages:${channelId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        },
        (payload) => {
          setMessages((prev) => [...prev, payload.new as Message]);
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        },
        (payload) => {
          setMessages((prev) =>
            prev.map((m) => (m.id === payload.new.id ? payload.new as Message : m))
          );
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'DELETE',
          schema: 'public',
          table: 'messages',
          filter: `channel_id=eq.${channelId}`,
        },
        (payload) => {
          setMessages((prev) => prev.filter((m) => m.id !== payload.old.id));
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [channelId, supabase]);

  return messages;
}
```

### Presence (Who's Online)
```typescript
// hooks/usePresence.ts
'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import type { RealtimePresenceState } from '@supabase/supabase-js';

interface PresenceUser {
  id: string;
  name: string;
  avatarUrl?: string;
  status: 'online' | 'away' | 'busy';
}

export function usePresence(roomId: string, currentUser: PresenceUser) {
  const [users, setUsers] = useState<PresenceUser[]>([]);
  const supabase = createClient();

  useEffect(() => {
    const channel = supabase.channel(`presence:${roomId}`, {
      config: { presence: { key: currentUser.id } },
    });

    channel
      .on('presence', { event: 'sync' }, () => {
        const state = channel.presenceState<PresenceUser>();
        const presentUsers = Object.values(state)
          .flat()
          .filter((u): u is PresenceUser => u !== undefined);
        setUsers(presentUsers);
      })
      .on('presence', { event: 'join' }, ({ key, newPresences }) => {
        console.log('User joined:', key, newPresences);
      })
      .on('presence', { event: 'leave' }, ({ key, leftPresences }) => {
        console.log('User left:', key, leftPresences);
      })
      .subscribe(async (status) => {
        if (status === 'SUBSCRIBED') {
          await channel.track(currentUser);
        }
      });

    return () => {
      channel.untrack();
      supabase.removeChannel(channel);
    };
  }, [roomId, currentUser, supabase]);

  return users;
}

// Usage
function OnlineUsers({ roomId }: { roomId: string }) {
  const currentUser = useCurrentUser();
  const users = usePresence(roomId, {
    id: currentUser.id,
    name: currentUser.name,
    status: 'online',
  });

  return (
    <div>
      <h3>Online ({users.length})</h3>
      {users.map((user) => (
        <div key={user.id}>{user.name}</div>
      ))}
    </div>
  );
}
```

### Broadcast (Ephemeral Messages)
```typescript
// hooks/useBroadcast.ts
'use client';

import { useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

export function useBroadcast<T>(channelName: string, eventName: string) {
  const supabase = createClient();

  const broadcast = useCallback(
    (payload: T) => {
      supabase.channel(channelName).send({
        type: 'broadcast',
        event: eventName,
        payload,
      });
    },
    [channelName, eventName, supabase]
  );

  return broadcast;
}

export function useBroadcastListener<T>(
  channelName: string,
  eventName: string,
  onMessage: (payload: T) => void
) {
  const supabase = createClient();

  useEffect(() => {
    const channel = supabase
      .channel(channelName)
      .on('broadcast', { event: eventName }, ({ payload }) => {
        onMessage(payload as T);
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [channelName, eventName, onMessage, supabase]);
}

// Usage: Cursor positions
function CollaborativeCanvas() {
  const broadcast = useBroadcast<{ x: number; y: number; userId: string }>(
    'canvas',
    'cursor'
  );

  useBroadcastListener<{ x: number; y: number; userId: string }>(
    'canvas',
    'cursor',
    (data) => {
      // Update cursor position for userId
      updateCursor(data.userId, data.x, data.y);
    }
  );

  const handleMouseMove = (e: MouseEvent) => {
    broadcast({ x: e.clientX, y: e.clientY, userId: currentUser.id });
  };
}
```

---

## Anti-Patterns

```typescript
// ❌ NEVER: Polling instead of real-time
useEffect(() => {
  const interval = setInterval(() => {
    fetch('/api/messages').then(r => r.json()).then(setMessages);
  }, 1000); // Wasteful!
  return () => clearInterval(interval);
}, []);

// ❌ NEVER: No reconnection logic
const ws = new WebSocket(url);
// What happens when it disconnects?

// ❌ NEVER: Sending sensitive data without auth
socket.emit('admin:action', { deleteAll: true });
// Anyone can send this!

// ✅ CORRECT: Verify on server
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!verifyToken(token)) return next(new Error('Unauthorized'));
  next();
});

// ❌ NEVER: Memory leaks - forgetting cleanup
useEffect(() => {
  const ws = new WebSocket(url);
  ws.onmessage = handleMessage;
  // No cleanup! Memory leak!
}, []);

// ✅ CORRECT: Always cleanup
useEffect(() => {
  const ws = new WebSocket(url);
  ws.onmessage = handleMessage;
  return () => ws.close();
}, []);
```

---

## Quick Reference

### When to Use What
| Need | Solution |
|------|----------|
| Server → Client only | SSE |
| Bidirectional | WebSocket / Socket.IO |
| Database sync | Supabase Realtime |
| Presence | Supabase / Socket.IO rooms |
| Cursor sync | Broadcast channels |
| Chat | Socket.IO with rooms |

### Supabase Realtime Event Types
| Event | Trigger |
|-------|---------|
| `INSERT` | New row added |
| `UPDATE` | Row modified |
| `DELETE` | Row removed |
| `*` | All changes |

### Connection States
| State | Meaning |
|-------|---------|
| `CONNECTING` | Initial connection |
| `OPEN` / `SUBSCRIBED` | Connected |
| `CLOSING` | Disconnect in progress |
| `CLOSED` | Disconnected |

### Checklist
- [ ] Reconnection logic with backoff
- [ ] Heartbeat/ping-pong for connection health
- [ ] Authentication before sensitive operations
- [ ] Cleanup subscriptions on unmount
- [ ] Error handling for parse failures
- [ ] Rate limiting on server
- [ ] Message validation/sanitization
