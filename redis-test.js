const Redis = require('ioredis');

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379', 10),
  // Remove password line entirely
  tls: process.env.REDIS_TLS_ENABLED === 'true' ? {} : undefined,
  connectTimeout: 10000,
});

redis.on('connect', () => {
  console.log('✅ Redis connected successfully!');
  redis.ping((err, result) => {
    console.log('PING response:', result);
    redis.disconnect();
    process.exit(0);
  });
});

redis.on('error', (err) => {
  console.error('❌ Redis connection error:', err.message);
  process.exit(1);
});

redis.on('ready', () => {
  console.log('✅ Redis is ready');
});

// Timeout after 15 seconds
setTimeout(() => {
  console.error('❌ Connection timeout after 15 seconds');
  redis.disconnect();
  process.exit(1);
}, 15000);
