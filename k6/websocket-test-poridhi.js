import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const connectionSuccessRate = new Rate('ws_connection_success_rate');
const messageSuccessRate = new Rate('ws_message_success_rate');
const messageLatency = new Trend('ws_message_latency');
const connectionErrors = new Counter('ws_connection_errors');
const messageErrors = new Counter('ws_message_errors');

export const options = {
  stages: [
    { duration: '1m', target: 50 },  // Ramp up to 50 users
    { duration: '3m', target: 50 },  // Stay at 50 users
    { duration: '1m', target: 100 }, // Ramp up to 100 users
    { duration: '3m', target: 100 }, // Stay at 100 users
    { duration: '1m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    'ws_connection_success_rate': ['rate>0.95'],
    'ws_message_success_rate': ['rate>0.95'],
    'ws_message_latency': ['p(95)<500'],
  },
};

export default function () {
  // Use the Poridhi lab load balancer URL for WebSocket server
  const url = 'wss://67ac2c9d1fcfb0b6f0fdcee7-lb-261.bm-southwest.lab.poridhi.io/ws';
  const params = {
    tags: { name: 'websocket-test-poridhi' },
  };

  const res = ws.connect(url, params, function (socket) {
    socket.on('open', () => {
      connectionSuccessRate.add(1);
      console.log('WebSocket connection established');
    });

    socket.on('message', (data) => {
      const message = JSON.parse(data);
      messageSuccessRate.add(1);
      messageLatency.add(message.timestamp ? Date.now() - new Date(message.timestamp).getTime() : 0);
    });

    socket.on('error', (e) => {
      connectionErrors.add(1);
      console.error('WebSocket error:', e);
    });

    socket.on('close', () => {
      console.log('WebSocket connection closed');
    });

    // Send messages every 2 seconds
    socket.setInterval(function () {
      const message = {
        type: 'message',
        content: `Test message from VU ${__VU}`,
        timestamp: new Date().toISOString(),
      };

      socket.send(JSON.stringify(message));
    }, 2000);

    // Keep the connection alive for 30 seconds
    socket.setTimeout(function () {
      socket.close();
    }, 30000);
  });

  check(res, {
    'Connected successfully': (r) => r && r.status === 101,
  });

  sleep(1);
} 