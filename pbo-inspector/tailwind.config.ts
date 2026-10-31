import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./lib/**/*.{ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        ink: "#12211C",
        moss: "#1F6F50",
        sand: "#EDE6D7",
        clay: "#C16F4A",
        ember: "#8E2F2F",
        mist: "#F7F5EF"
      },
      boxShadow: {
        panel: "0 20px 60px rgba(18, 33, 28, 0.12)"
      },
      fontFamily: {
        sans: ["'IBM Plex Sans'", "ui-sans-serif", "system-ui", "sans-serif"],
        display: ["'Space Grotesk'", "'IBM Plex Sans'", "ui-sans-serif", "sans-serif"]
      }
    }
  },
  plugins: []
};

export default config;
