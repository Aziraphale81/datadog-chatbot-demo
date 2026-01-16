// Datadog APM instrumentation for Next.js
// This file is automatically loaded by Next.js 13.2+ before any other code runs
// See: https://nextjs.org/docs/app/building-your-application/optimizing/instrumentation

export async function register() {
  // Only run tracer on the server side
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const tracer = await import('dd-trace');
    
    tracer.default.init({
      logInjection: true,
      runtimeMetrics: true,
      profiling: true,
      appsec: true,
    });
    
    console.log('✅ Datadog APM tracer initialized for Next.js');
  }
}










