/** @type {import('next').NextConfig} */
const nextConfig = {
  // Served under projectloonybin.com/pbo via the Cloudflare tunnel path route.
  basePath: "/pbo",
  experimental: {
    typedRoutes: true
  }
};

export default nextConfig;
