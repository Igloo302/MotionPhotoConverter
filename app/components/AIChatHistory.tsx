import { useEffect, useState } from 'react';
import { ChatService } from '../services/ChatService';
import { Chat } from '../models/Chat';

function AIChatHistory() {
  const [chats, setChats] = useState<Chat[]>([]);
  const chatService = new ChatService();

  useEffect(() => {
    async function fetchChats() {
      const history = await chatService.getChatHistory();
      setChats(history);
    }
    fetchChats();
  }, []);

  // 渲染逻辑
}