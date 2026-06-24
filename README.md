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
- The listing owner, 
or
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

## Development

- Linting: `bundle exec rubocop`
- Security audit: `bundle exec brakeman`
- Dependency audit: `bundle exec bundler-audit`