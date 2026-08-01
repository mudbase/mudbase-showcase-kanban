import { useEffect, useState } from "react";
import { getMudbaseSocket, type SocketStatus } from "@/lib/socket";

/**
 * Tracks the shared Mudbase socket's connection status for UI (e.g. a small
 * "reconnecting…" indicator). The connection itself is established by
 * authStore.initialize()/login()/logout() as soon as a token exists — this
 * hook only observes, it never calls connect()/disconnect() itself, since
 * multiple screens mount it concurrently and only one owner should manage the
 * socket's lifecycle.
 */
export function useSocket(): { status: SocketStatus } {
  const [status, setStatus] = useState<SocketStatus>(getMudbaseSocket().connected ? "connected" : "disconnected");

  useEffect(() => {
    const socket = getMudbaseSocket();
    return socket.onStatus(setStatus);
  }, []);

  return { status };
}
