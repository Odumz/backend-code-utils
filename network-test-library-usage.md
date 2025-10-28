# Network Test Utility Library

A lightweight, cross-platform TypeScript library for testing network speed and detecting provider information. Works seamlessly in both browser and Node.js environments.

## Features

- ✅ **Speed Testing** - Measure download/upload speeds and latency
- 🎯 **Network Quality Analysis** - Categorizes connection quality with recommendations
- 🌍 **Provider Detection** - Identifies ISP/network provider (MTN, Airtel, Glo, etc.)
- 🔄 **Cross-Platform** - Works in browsers and Node.js
- 🪶 **Lightweight** - No external dependencies, minimal footprint
- ⚙️ **Configurable** - Customizable test parameters
- 🛡️ **Type-Safe** - Full TypeScript support

## Installation

```bash
npm install network-test-utility
# or
yarn add network-test-utility
# or
pnpm add network-test-utility
```

## Quick Start

```typescript
import { NetworkTester, getNetworkStatus } from 'network-test-utility';

// Simple network status check
const status = await getNetworkStatus();
console.log(`Network is ${status.isGood ? 'good' : 'bad'}`);
console.log(`Provider: ${status.provider}`);
console.log(`Speed: ${status.speed} Mbps`);
```

## Usage Examples

### Full Speed Test

```typescript
const tester = new NetworkTester();
const result = await tester.runSpeedTest();

console.log(`Download: ${result.downloadSpeed} Mbps`);
console.log(`Upload: ${result.uploadSpeed} Mbps`);
console.log(`Latency: ${result.latency} ms`);
console.log(`Jitter: ${result.jitter} ms`);
```

### Analyze Network Quality

```typescript
const quality = tester.analyzeQuality(result);

console.log(`Quality: ${quality.quality}`);
console.log(`Recommendation: ${quality.recommendation}`);
```

**Quality Levels:**
- `excellent` - Perfect for 4K streaming, gaming, and large file transfers
- `good` - Suitable for HD streaming, video calls, and online gaming
- `fair` - Good for browsing and SD streaming
- `poor` - Basic browsing only
- `very-poor` - Very slow connection

### Get Network Provider Information

```typescript
const provider = await tester.getNetworkProvider();

console.log(`Provider: ${provider.name}`);
console.log(`Country: ${provider.country}`);
console.log(`ISP: ${provider.isp}`);
console.log(`ASN: ${provider.asn}`);
```

**Supported Providers** (Auto-detected):
- MTN, Airtel, Glo, 9mobile (Nigeria)
- Vodafone, Orange, T-Mobile, AT&T, Verizon (International)
- And many more...

### Quick Network Check

```typescript
const { isOnline, latency } = await tester.quickCheck();

if (isOnline) {
  console.log(`Network is online with ${latency}ms latency`);
} else {
  console.log('Network is offline');
}
```

### Custom Configuration

```typescript
const tester = new NetworkTester({
  downloadTestDuration: 10,  // seconds
  uploadTestDuration: 5,      // seconds
  latencyTestCount: 10,       // number of ping tests
  testFileSize: 1024 * 500    // 500KB for upload test
});

const result = await tester.runSpeedTest();
```

## API Reference

### `NetworkTester`

Main class for network testing.

#### Constructor Options

```typescript
interface SpeedTestOptions {
  downloadTestDuration?: number;  // Default: 5 seconds
  uploadTestDuration?: number;    // Default: 5 seconds
  latencyTestCount?: number;      // Default: 5
  testFileSize?: number;          // Default: 100KB
}
```

#### Methods

- `runSpeedTest()` - Run complete speed test (download, upload, latency)
- `testLatency()` - Test network latency only
- `testDownloadSpeed()` - Test download speed only
- `testUploadSpeed()` - Test upload speed only
- `analyzeQuality(result)` - Analyze network quality from test results
- `getNetworkProvider()` - Detect network provider information
- `quickCheck()` - Quick online/offline check with latency

### Helper Functions

```typescript
// Check if network is good (excellent or good quality)
const isGood = await isNetworkGood();

// Get comprehensive network status
const status = await getNetworkStatus();
```

### Return Types

```typescript
interface SpeedTestResult {
  downloadSpeed: number;  // Mbps
  uploadSpeed: number;    // Mbps
  latency: number;        // ms
  jitter: number;         // ms
  timestamp: number;
}

interface NetworkQuality {
  quality: 'excellent' | 'good' | 'fair' | 'poor' | 'very-poor';
  downloadSpeed: number;
  uploadSpeed: number;
  latency: number;
  recommendation: string;
}

interface NetworkProvider {
  name: string | null;
  country: string | null;
  isp: string | null;
  asn: string | null;
}
```

## Use Cases

### Monitor User Connection Quality

```typescript
const tester = new NetworkTester();
const result = await tester.runSpeedTest();
const quality = tester.analyzeQuality(result);

if (quality.quality === 'poor' || quality.quality === 'very-poor') {
  // Show warning to user
  alert('Your internet connection is slow. Some features may not work properly.');
}
```

### Adaptive Video Quality

```typescript
const status = await getNetworkStatus();

let videoQuality;
if (status.speed >= 25) {
  videoQuality = '1080p';
} else if (status.speed >= 10) {
  videoQuality = '720p';
} else {
  videoQuality = '480p';
}

console.log(`Recommended video quality: ${videoQuality}`);
```

### Analytics & Debugging

```typescript
const tester = new NetworkTester();
const [speedResult, provider] = await Promise.all([
  tester.runSpeedTest(),
  tester.getNetworkProvider()
]);

// Send to analytics
analytics.track('network_test', {
  download_speed: speedResult.downloadSpeed,
  upload_speed: speedResult.uploadSpeed,
  latency: speedResult.latency,
  provider: provider.name,
  country: provider.country
});
```

## Browser Support

- ✅ Chrome/Edge (latest)
- ✅ Firefox (latest)
- ✅ Safari (latest)
- ✅ Mobile browsers (iOS Safari, Chrome Mobile)

## Node.js Support

- ✅ Node.js 14+
- ✅ Works with ES modules and CommonJS

## Performance Considerations

- Speed tests consume bandwidth - use appropriate test durations
- Provider detection makes external API calls (cached recommended)
- Quick check is lightweight and suitable for frequent polling
- Tests run sequentially to avoid network congestion

## Privacy & Security

- No data is stored or transmitted to third parties
- Provider detection uses public IP lookup services
- All tests use HTTPS endpoints
- No tracking or analytics built-in

## Limitations

- Speed test accuracy depends on test server availability
- Provider detection requires internet connectivity
- Results may vary based on network conditions and server load
- Some corporate firewalls may block test endpoints

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - feel free to use in personal and commercial projects.

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

Made with ❤️ for better network testing
