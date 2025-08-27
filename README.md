# Pokemon Frontend

A React-based web application for browsing and filtering Pokemon data.

## Features

- 🔍 **Search by Name** - Find Pokemon by typing their name
- 🏷️ **Filter by Type** - Filter Pokemon by their elemental type
- ⭐ **Legendary Filter** - Show only legendary or non-legendary Pokemon
- 📱 **Responsive Design** - Works on desktop, tablet, and mobile
- 🎨 **Modern UI** - Beautiful glassmorphism design with animations
- ⚡ **Real-time Filtering** - Instant results as you type or change filters
- 🐙 **Error Handling** - Graceful handling of network issues

## Technology Stack

- **React 18** - Modern React with functional components and hooks
- **CSS3** - Custom styling with animations and responsive design
- **Docker** - Containerized deployment
- **Nginx** - Production web server

## Prerequisites

- Node.js (v18 or later)
- npm or yarn
- Backend API running (see backend README)

## Development Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Environment Configuration

Create a `.env` file in the root directory:

```bash
cp .env.example .env
```

Update the API URL in `.env`:
```
REACT_APP_API_URL=http://localhost:3001
```

### 3. Start Development Server

```bash
npm start
```

The application will open at `http://localhost:3000`

## Docker Setup

### Build and Run

```bash
# Build the image
docker build -t pokemon-frontend .

# Run the container
docker run -p 3000:3000 pokemon-frontend
```

### Using Docker Compose

For full-stack deployment (includes backend):

```bash
# Start both frontend and backend
docker-compose up -d

# Stop all services
docker-compose down
```

## Project Structure

```
pokemon-frontend/
├── public/
│   └── index.html
├── src/
│   ├── components/
│   │   ├── PokemonCard.js      # Individual Pokemon card
│   │   ├── PokemonCard.css
│   │   ├── FilterBar.js        # Search and filter controls
│   │   ├── FilterBar.css
│   │   ├── LoadingSpinner.js   # Pokeball loading animation
│   │   └── LoadingSpinner.css
│   ├── App.js                  # Main application component
│   ├── App.css
│   ├── index.js               # React entry point
│   └── index.css
├── nginx.conf                 # Production web server config
├── Dockerfile
├── docker-compose.yml
├── package.json
└── README.md
```

## Available Scripts

- `npm start` - Start development server
- `npm run build` - Build for production
- `npm test` - Run tests
- `npm run docker:build` - Build Docker image
- `npm run docker:run` - Run Docker container

## Features in Detail

### Search and Filtering

The application provides three ways to filter Pokemon:

1. **Name Search**: Type any part of a Pokemon's name
2. **Type Filter**: Select from available Pokemon types
3. **Legendary Filter**: Show all, legendary only, or non-legendary only

Filters can be combined for more specific results.

### Pokemon Cards

Each Pokemon is displayed in an attractive card showing:

- Pokemon image/sprite
- Name and ID number
- Type badges with color coding
- Special legendary badge for legendary Pokemon

### Responsive Design

The application adapts to different screen sizes:

- Desktop: Multi-column grid layout
- Tablet: Responsive grid with fewer columns
- Mobile: Single column layout with touch-friendly controls

### Error Handling

- Connection errors show a user-friendly message
- Missing images are handled gracefully
- Loading states with animated Pokeball spinner
- Empty results show helpful messaging

## Environment Variables

- `REACT_APP_API_URL` - Backend API URL (default: http://localhost:3001)

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## Production Deployment

The Docker image uses a multi-stage build:

1. **Build stage**: Compiles the React application
2. **Production stage**: Serves files with Nginx

Features included in production:
- Gzip compression
- Static asset caching
- Security headers
- Client-side routing support
