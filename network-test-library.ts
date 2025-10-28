/**
 * Network Test Utility Library
 * A lightweight, cross-platform library for testing network speed and detecting provider information
 */

// ==================== Types ====================

export interface SpeedTestResult {
  downloadSpeed: number; // Mbps
  uploadSpeed: number; // Mbps
  latency: number; // ms
  jitter: number; // ms
  timestamp: number;
}

export interface NetworkQuality {
  quality: 'excellent' | 'good' | 'fair' | 'poor' | 'very-poor';
  downloadSpeed: number;
  uploadSpeed: number;
  latency: number;
  recommendation: string;
}

export interface NetworkProvider {
  name: string | null;
  country: string | null;
  isp: string | null;
  asn: string | null;
}

export interface SpeedTestOptions {
  downloadTestDuration?: number; // seconds
  uploadTestDuration?: number; // seconds
  latencyTestCount?: number;
  testFileSize?: number; // bytes for upload test
}

// ==================== Constants ====================

const DEFAULT_OPTIONS: Required<SpeedTestOptions> = {
  downloadTestDuration: 5,
  uploadTestDuration: 5,
  latencyTestCount: 5,
  testFileSize: 1024 * 100, // 100KB
};

// Quality thresholds
const QUALITY_THRESHOLDS = {
  excellent: { download: 50, upload: 10, latency: 30 },
  good: { download: 25, upload: 5, latency: 50 },
  fair: { download: 10, upload: 2, latency: 100 },
  poor: { download: 5, upload: 1, latency: 200 },
};

// ==================== Network Test Class ====================

export class NetworkTester {
  private options: Required<SpeedTestOptions>;
  private isBrowser: boolean;

  constructor(options: SpeedTestOptions = {}) {
    this.options = { ...DEFAULT_OPTIONS, ...options };
    this.isBrowser = typeof window !== 'undefined' && typeof document !== 'undefined';
  }

  /**
   * Run a complete network speed test
   */
  async runSpeedTest(): Promise<SpeedTestResult> {
    const latency = await this.testLatency();
    const downloadSpeed = await this.testDownloadSpeed();
    const uploadSpeed = await this.testUploadSpeed();
    
    return {
      downloadSpeed,
      uploadSpeed,
      latency: latency.avg,
      jitter: latency.jitter,
      timestamp: Date.now(),
    };
  }

  /**
   * Test network latency (ping)
   */
  async testLatency(): Promise<{ avg: number; jitter: number; min: number; max: number }> {
    const testUrls = [
      'https://www.cloudflare.com/cdn-cgi/trace',
      'https://www.google.com/generate_204',
      'https://1.1.1.1/cdn-cgi/trace',
    ];

    const latencies: number[] = [];
    
    for (let i = 0; i < this.options.latencyTestCount; i++) {
      const url = testUrls[i % testUrls.length];
      const start = performance.now();
      
      try {
        if (this.isBrowser) {
          await fetch(url, { method: 'HEAD', cache: 'no-cache' });
        } else {
          const https = await import('https');
          await new Promise((resolve, reject) => {
            const req = https.request(url, { method: 'HEAD' }, resolve);
            req.on('error', reject);
            req.end();
          });
        }
        
        const end = performance.now();
        latencies.push(end - start);
      } catch (error) {
        console.warn('Latency test failed for:', url);
      }
    }

    if (latencies.length === 0) {
      throw new Error('All latency tests failed');
    }

    const avg = latencies.reduce((a, b) => a + b, 0) / latencies.length;
    const min = Math.min(...latencies);
    const max = Math.max(...latencies);
    
    // Calculate jitter (average deviation from mean)
    const jitter = latencies.reduce((sum, lat) => sum + Math.abs(lat - avg), 0) / latencies.length;

    return { avg, jitter, min, max };
  }

  /**
   * Test download speed
   */
  async testDownloadSpeed(): Promise<number> {
    // Using random data endpoints for testing
    const testUrls = [
      'https://speed.cloudflare.com/__down?bytes=10000000', // 10MB
      'https://proof.ovh.net/files/10Mb.dat',
    ];

    let totalBytes = 0;
    const startTime = performance.now();
    const endTime = startTime + this.options.downloadTestDuration * 1000;

    try {
      while (performance.now() < endTime) {
        for (const url of testUrls) {
          if (performance.now() >= endTime) break;

          try {
            const response = await fetch(url, { cache: 'no-cache' });
            
            if (this.isBrowser && response.body) {
              const reader = response.body.getReader();
              
              while (performance.now() < endTime) {
                const { done, value } = await reader.read();
                if (done) break;
                totalBytes += value?.length || 0;
              }
              
              reader.cancel();
            } else {
              const buffer = await response.arrayBuffer();
              totalBytes += buffer.byteLength;
            }
          } catch (error) {
            console.warn('Download test failed for:', url);
          }
        }
      }

      const duration = (performance.now() - startTime) / 1000; // seconds
      const speedBps = totalBytes / duration;
      const speedMbps = (speedBps * 8) / (1024 * 1024); // Convert to Mbps

      return Math.round(speedMbps * 100) / 100;
    } catch (error) {
      console.error('Download speed test failed:', error);
      return 0;
    }
  }

  /**
   * Test upload speed
   */
  async testUploadSpeed(): Promise<number> {
    const testUrl = 'https://httpbin.org/post';
    const data = new Uint8Array(this.options.testFileSize);
    
    // Fill with random data
    for (let i = 0; i < data.length; i++) {
      data[i] = Math.floor(Math.random() * 256);
    }

    let totalBytes = 0;
    const startTime = performance.now();
    const endTime = startTime + this.options.uploadTestDuration * 1000;

    try {
      while (performance.now() < endTime) {
        try {
          await fetch(testUrl, {
            method: 'POST',
            body: data,
            headers: { 'Content-Type': 'application/octet-stream' },
          });
          
          totalBytes += data.length;
        } catch (error) {
          console.warn('Upload test request failed');
          break;
        }
      }

      const duration = (performance.now() - startTime) / 1000;
      const speedBps = totalBytes / duration;
      const speedMbps = (speedBps * 8) / (1024 * 1024);

      return Math.round(speedMbps * 100) / 100;
    } catch (error) {
      console.error('Upload speed test failed:', error);
      return 0;
    }
  }

  /**
   * Analyze network quality based on speed test results
   */
  analyzeQuality(result: SpeedTestResult): NetworkQuality {
    let quality: NetworkQuality['quality'] = 'very-poor';
    let recommendation = '';

    if (
      result.downloadSpeed >= QUALITY_THRESHOLDS.excellent.download &&
      result.uploadSpeed >= QUALITY_THRESHOLDS.excellent.upload &&
      result.latency <= QUALITY_THRESHOLDS.excellent.latency
    ) {
      quality = 'excellent';
      recommendation = 'Perfect for 4K streaming, gaming, and large file transfers.';
    } else if (
      result.downloadSpeed >= QUALITY_THRESHOLDS.good.download &&
      result.uploadSpeed >= QUALITY_THRESHOLDS.good.upload &&
      result.latency <= QUALITY_THRESHOLDS.good.latency
    ) {
      quality = 'good';
      recommendation = 'Suitable for HD streaming, video calls, and online gaming.';
    } else if (
      result.downloadSpeed >= QUALITY_THRESHOLDS.fair.download &&
      result.uploadSpeed >= QUALITY_THRESHOLDS.fair.upload &&
      result.latency <= QUALITY_THRESHOLDS.fair.latency
    ) {
      quality = 'fair';
      recommendation = 'Good for browsing and SD streaming. May experience delays in video calls.';
    } else if (
      result.downloadSpeed >= QUALITY_THRESHOLDS.poor.download &&
      result.uploadSpeed >= QUALITY_THRESHOLDS.poor.upload
    ) {
      quality = 'poor';
      recommendation = 'Basic browsing only. Video streaming and calls will be problematic.';
    } else {
      quality = 'very-poor';
      recommendation = 'Very slow connection. Consider switching networks or contacting your ISP.';
    }

    return {
      quality,
      downloadSpeed: result.downloadSpeed,
      uploadSpeed: result.uploadSpeed,
      latency: result.latency,
      recommendation,
    };
  }

  /**
   * Detect network provider information
   */
  async getNetworkProvider(): Promise<NetworkProvider> {
    try {
      // Try multiple IP detection services
      const services = [
        'https://ipapi.co/json/',
        'https://ip-api.com/json/',
      ];

      for (const service of services) {
        try {
          const response = await fetch(service);
          const data = await response.json();

          // Normalize response from different services
          if (service.includes('ipapi.co')) {
            return {
              name: this.normalizeProviderName(data.org || data.asn),
              country: data.country_name || null,
              isp: data.org || null,
              asn: data.asn || null,
            };
          } else if (service.includes('ip-api.com')) {
            return {
              name: this.normalizeProviderName(data.isp || data.org),
              country: data.country || null,
              isp: data.isp || null,
              asn: data.as || null,
            };
          }
        } catch (error) {
          console.warn(`Failed to fetch from ${service}`);
          continue;
        }
      }

      return { name: null, country: null, isp: null, asn: null };
    } catch (error) {
      console.error('Failed to detect network provider:', error);
      return { name: null, country: null, isp: null, asn: null };
    }
  }

  /**
   * Normalize provider name to common formats
   */
  private normalizeProviderName(orgString: string | null): string | null {
    if (!orgString) return null;

    const lower = orgString.toLowerCase();
    
    // Common Nigerian providers
    if (lower.includes('mtn')) return 'MTN';
    if (lower.includes('airtel')) return 'Airtel';
    if (lower.includes('glo') || lower.includes('globacom')) return 'Glo';
    if (lower.includes('9mobile') || lower.includes('etisalat')) return '9mobile';
    
    // International providers
    if (lower.includes('vodafone')) return 'Vodafone';
    if (lower.includes('orange')) return 'Orange';
    if (lower.includes('verizon')) return 'Verizon';
    if (lower.includes('at&t') || lower.includes('att')) return 'AT&T';
    if (lower.includes('t-mobile')) return 'T-Mobile';
    if (lower.includes('telkom')) return 'Telkom';
    
    // Return cleaned version if no match
    return orgString.replace(/^(AS\d+\s+)/i, '').trim();
  }

  /**
   * Quick network check (lightweight version)
   */
  async quickCheck(): Promise<{ isOnline: boolean; latency: number }> {
    try {
      const start = performance.now();
      await fetch('https://www.google.com/generate_204', { 
        method: 'HEAD',
        cache: 'no-cache' 
      });
      const latency = performance.now() - start;
      
      return { isOnline: true, latency };
    } catch (error) {
      return { isOnline: false, latency: -1 };
    }
  }
}

// ==================== Utility Functions ====================

/**
 * Quick function to check if network is good
 */
export async function isNetworkGood(): Promise<boolean> {
  const tester = new NetworkTester();
  const result = await tester.runSpeedTest();
  const quality = tester.analyzeQuality(result);
  
  return ['excellent', 'good'].includes(quality.quality);
}

/**
 * Get simple network status
 */
export async function getNetworkStatus(): Promise<{
  isGood: boolean;
  quality: string;
  speed: number;
  provider: string | null;
}> {
  const tester = new NetworkTester();
  const [speedResult, provider] = await Promise.all([
    tester.runSpeedTest(),
    tester.getNetworkProvider(),
  ]);
  
  const quality = tester.analyzeQuality(speedResult);
  
  return {
    isGood: ['excellent', 'good'].includes(quality.quality),
    quality: quality.quality,
    speed: speedResult.downloadSpeed,
    provider: provider.name,
  };
}

// ==================== Export ====================

export default NetworkTester;
