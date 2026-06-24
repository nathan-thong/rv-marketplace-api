# RV Marketplace API

A RESTful API for a two-sided RV rental marketplace built with Ruby on Rails. Connects RV owners (lessors) with renters (hirers) for listing management, lead generation, messaging, and booking requests.

## Requirements

- Ruby 3.3.11
- Rails 8.1.3
- PostgreSQL 12+
- Bundler

## Setup

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd rv-marketplace
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your local database credentials and JWT secret (or run `bundle exec rails secret` to generate one).

4. **Create and migrate the database**
   ```bash
   bundle exec rails db:create
   bundle exec rails db:migrate
   ```

5. **Start the server**
   ```bash
   bundle exec rails s
   ```
   The API will be available at `http://localhost:3000`.

## API Endpoints

### Authentication
- `POST /register` - Register a new user
- `POST /login` - Login and receive JWT token

### Listings
- `GET /listings` - List all RV listings
- `GET /listings/:id` - Show a single listing
- `POST /listings` - Create a new listing (authenticated)
- `PUT/PATCH /listings/:id` - Update a listing (owner only)
- `DELETE /listings/:id` - Delete a listing (owner only)

### Bookings
- `POST /listings/:listing_id/bookings` - Create a booking request (authenticated)
- `GET /bookings` - List user's bookings (as hirer or owner)
- `PATCH /bookings/:id/confirm` - Confirm a booking (owner only)
- `PATCH /bookings/:id/reject` - Reject a booking (owner only)

### Messages
- `GET /listings/:listing_id/messages` - List messages for a listing (authenticated participant only)
- `POST /listings/:listing_id/messages` - Create a message for a listing (authenticated participant only)

Participant means:
- The listing owner
- A user who has a booking on that listing


## Authentication

Token-based authentication via JWT. After registering or logging in, include the token in the Authorization header:
```
Authorization: Bearer <token>
```

Tokens expire after 24 hours.

## Testing

Run the test suite:

```bash
bundle exec rspec
```

## API Documentation

Generate documentation:
```bash
bundle exec rake rswag:specs:swaggerize
```

Swagger/OpenAPI documentation:
- http://localhost:3000/api-docs


## Frontend (Waypoint)

A static single-page client is bundled in `public/frontend/` and served directly by Rails at `/frontend/index.html`. No separate build step or deployment is needed — because it lives in `public/`, it is served by the same Rails process and makes same-origin API requests.

### Features

- **Listings marketplace** — browse all RV listings in a responsive card grid
- **Search & sort** — filter by title/location/description with live client-side search; sort by newest, oldest, price ascending, or price descending
- **Statistics bar** — live counts of total listings, unique locations, and price range
- **Authentication** — login and register via modal; JWT is persisted to `localStorage` for simplicity; a production deployment should prefer HttpOnly cookies to mitigate XSS token theft.
- **Listing management** — authenticated owners can create, edit, and delete their own listings via modal forms
- **Booking workflow** — hirers can submit a booking request (with start/end date picker) from any listing detail view; owners can confirm or reject pending requests from the Bookings panel
- **Bookings panel** — dedicated view showing all bookings where the current user is either the hirer or the listing owner

### Accessing the frontend

Start the Rails server and open:
```
http://localhost:3000/frontend/index.html
```

### Pointing at a different API

By default the page talks to the same host it is served from (relative URLs). To point it at a different deployed instance, append `?api=<absolute-url>`:
```
http://localhost:3000/frontend/index.html?api=https://your-api.example.com
```

## Development

- Linting: `bundle exec rubocop`
- Security audit: `bundle exec brakeman`
- Dependency audit: `bundle exec bundler-audit`