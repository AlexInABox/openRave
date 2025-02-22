import * as WebSocket from 'ws';

const wss = new WebSocket.Server({ port: 3000 });
let rooms: { [key: string]: Room } = {};

interface Room {
  videoId: string;
  timestamp: number;
  state: 'playing' | 'paused';
  users: WebSocket[];
}

setInterval(() => {
  for (const [roomId, room] of Object.entries(rooms)) {
    if (room.state === 'playing') {
      room.timestamp += 1;
    }
  }
}, 1000);


wss.on('connection', function connection(ws: WebSocket, request) {
  console.log('New client connected to room ' + getRoomId(request.url||''));

  const roomId: string = getRoomId(request.url||'');
  if (!rooms[roomId]) {
    rooms[roomId] = {
      videoId: 'dHcoigGFOGY', //Just a default song
      timestamp: 0,
      state: 'paused',
      users: [ws]
    };
  } else {
    rooms[roomId].users.push(ws);
    
  }
  updateUserOnCurrentRoomState(ws, rooms[roomId]);



  ws.on('message', (message: string) => {
    console.log(`Received message: ${message}`);

    if (message.toString() === 'keepalive') {
      ws.send('keepalive');
      return;
    }
    if (message.toString().startsWith('videoId:')) {
      rooms[roomId].videoId = message.toString().split(': ')[1];
      rooms[roomId].state = 'paused';

      //now send the videoId to all users in the room including the sender
      rooms[roomId].users.forEach(client => {
        client.send(message.toString());
      });
      return;
    }
    if (message.toString().startsWith('seek:')) {
      rooms[roomId].timestamp = parseFloat(message.toString().split(': ')[1]);
    }
    if (message.toString() === 'playing') {
      rooms[roomId].state = 'playing';
    }
    if (message.toString() === 'paused') {
      rooms[roomId].state = 'paused';
    }
    if (message.toString() === 'ended') {
      rooms[roomId].state = 'paused';
      return;
    }

    rooms[roomId].users.forEach(client => {
      if (client !== ws) {
        client.send(message.toString());
      }
    });
  });

  ws.on('close', () => {
    console.log('Client disconnected');
    
    if (!rooms[roomId]) return;

    rooms[roomId].users = rooms[roomId].users.filter(user => user !== ws);
    
    if (rooms[roomId].users.length === 0) {
      delete rooms[roomId];
    }
  });
});

function getRoomId(path: string): string {
  const re: RegExp = /room=([^&/]*)/;
  const match = re.exec(path);
  return match ? match[1] : 'default';
}

async function updateUserOnCurrentRoomState(ws: WebSocket, room: Room): Promise<void> {
  const videoId: string = room.videoId;
  const timestamp: number = room.timestamp;
  const state: "playing" | "paused" = room.state; 

  ws.send("catchUp: " + videoId + " " + timestamp + " " + state);
}