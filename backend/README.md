# Benefits Management Backend API

A Phoenix/Elixir backend API for an application providing user register and authentication, product (benefits) fetching, and order (subscription) management capabilities.

## Prerequisites

- Elixir 1.15+
- Erlang/OTP 26+
- PostgreSQL 13+
- Docker & Docker Compose (for database)

## Development Setup

1. **Start PostgreSQL database:**
   ```bash
   docker-compose up -d
   ```

2. **Install dependencies and setup database:**
   ```bash
   mix setup
   ```

3. **Start Phoenix server:**
   ```bash
   mix phx.server
   ```

4. **Access the application:**
   - API: [`localhost:4000`](http://localhost:4000)
   - Phoenix LiveDashboard (dev only): [`localhost:4000/dev/dashboard`](http://localhost:4000/dev/dashboard)

## Testing

```bash
# Run all tests
mix test
```

## API Documentation

## Frontend Compatibility Endpoints (Legacy)

The following endpoints maintain compatibility with the existing frontend but have significant limitations:

### Legacy Product Endpoint
```http
GET /products
```

**Limitations:**
- No versioning in URL path
- Inconsistent response structure compared to upgraded API
- No authentication requirements

### Legacy User Endpoint
```http
GET /users/{username}
```

**Limitations:**
- Exposes user data without authentication
- Creates users automatically if they don't exist (security risk)
- Uses username instead of proper user ID
- No validation of username format

### Legacy Order Creation
```http
POST /orders
Content-Type: application/json

{
  "order": {
    "items": ["netflix", "spotify"],
    "user_id": "username_here"
  }
}
```

**Major Limitations:**
1. **Security Issues:**
    - No authentication required
    - User identification by username instead of secure token
    - No authorization checks

2. **Data Integrity Issues:**
    - Users created automatically without proper validation
    - No email requirement for user creation
    - Weak user identification mechanism

3. **API Design Issues:**
    - Inconsistent with REST conventions
    - Mixed responsibility (creates users and orders in single endpoint)
    - No proper error handling for invalid users

### Authentication Endpoints (Upgraded API)

#### Register User
```http
POST /api/auth/register
Content-Type: application/json

{
  "user": {
    "username": "john_doe",
    "email": "john@example.com", 
    "password": "SecurePass123!"
  }
}
```

#### Login User
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "john_doe",
  "password": "SecurePass123!"
}
```

**Response:**
```json
{
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "username": "john_doe",
    "email": "john@example.com",
    "balance": "1000.00"
  },
  "token": "eyJhbGciOiJIUzI1NiIs..."
}
```

#### Refresh Token
```http
POST /api/auth/refresh
Authorization: Bearer <token>
```

#### Logout
```http
POST /api/auth/logout  
Authorization: Bearer <token>
```

### Product Endpoints

#### List Products
```http
GET /api/products
```

**Response:**
```json
{
  "products": [
    {
      "id": "netflix",
      "name": "Netflix Subscription", 
      "price": "15.99"
    }
  ]
}
```

### User Endpoints (Authenticated)

#### Get Current User
```http
GET /api/users/me
Authorization: Bearer <token>
```

**Response:**
```json
{
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "username": "john_doe",
    "email": "john@example.com",
    "balance": "1000.00",
    "product_ids": ["netflix", "spotify"]
  }
}
```

### Order Endpoints

#### Create Order (Authenticated)
```http
POST /api/orders
Authorization: Bearer <token>
Content-Type: application/json

{
  "order": {
    "items": ["netflix", "spotify"]
  }
}
```

**Response:**
```json
{
  "order": {
    "items": ["netflix", "spotify"]
  }
}
```

## Upgraded API Improvements

The new authenticated API addresses the legacy issues:

### Security Enhancements
- **JWT Authentication:** All sensitive operations require Bearer token
- **Proper User Registration:** Email and password validation with secure hashing
- **Authorization:** Users can only access their own data
- **CORS Protection:** Configured for frontend origin

### Data Integrity  
- **Validated User Creation:** Requires email, secure password, and username
- **UUID-based IDs:** Secure, non-sequential user identification
- **Transactional Operations:** Order creation with balance validation and rollback
- **Schema Validation:** Comprehensive input validation at all levels

### API Design
- **Consistent URL Structure:** `/api/v1/*` pattern ready for versioning
- **Proper HTTP Status Codes:** 200, 201, 400, 401, 403, 404, 422
- **Standardized Error Responses:** Consistent error message format
- **Resource Separation:** Clear endpoint responsibilities

## Architecture

### Database Schema
- **Users:** UUID primary key, email/username uniqueness, hashed passwords
- **Products:** String-based product IDs, decimal pricing
- **Orders:** UUID-based with user association and total calculation
- **Order Items:** Junction table with price snapshot
- **User Products:** Many-to-many relationship tracking purchases

### Business Logic
- **User Balance Management:** 1000.00 default balance with transaction safety
- **Duplicate Purchase Prevention:** Users cannot buy the same product twice
- **Order Transaction Integrity:** All-or-nothing order processing with automatic rollback

### Security Features
- **Password Hashing:** Bcrypt with secure salts
- **JWT Tokens:** Stateless authentication with configurable expiration
- **Input Validation:** Comprehensive validation at controller and schema levels
- **SQL Injection Protection:** Ecto parameterized queries

## Assumptions Made

1. **Single Currency:** All prices in EUR with 2 decimal precision
2. **One-time Purchases:** Products are purchased once per user (no quantities)
3. **Static Product Catalog:** Products are pre-seeded, no dynamic product creation
4. **Simple User Roles:** No admin/customer distinction in current implementation
5. **Default Balance:** New users start with 1000.00 virtual currency
6**Development Environment:** Database runs in Docker for local development
7**JWT Security:** Single secret key for token signing (should use rotation in production)

## API Conventions

This backend exposes an authenticated API under `/api` and a small set of legacy endpoints (deprecated) for compatibility with the Frontend prototype UI.

### Envelope style

- Requests (write operations) are resource-wrapped:
    - Example (create order, authenticated):
      ```json
      {
        "order": {
          "items": ["netflix", "spotify"]
        }
      }
      ```
- Responses are resource-rooted:
    - Single resource: `{"user": {...}}`, `{"order": {...}}`
    - Collections: `{"products": [...]}`

Legacy endpoints preserve the original prototype contracts and may differ in naming (see “Legacy compatibility”).

### Identifiers

- IDs are opaque strings (UUID/ULID-like). Clients must treat them as strings and not infer meaning.
- Upgraded user responses include both:
    - `id` (opaque) for backend references
    - `username` for display
- Legacy `user_id` equals the username (string). Modern `user_id` fields (e.g., on orders) are opaque IDs.

### Authentication

- Upgrated protected endpoints require a Bearer JWT via `Authorization: Bearer <token>`.
- On missing/invalid/expired token:
  ```json
  {
    "error": "unauthenticated",
    "message": "Authentication required"
  }
  ```

### Monetary values

- All monetary values (e.g., `balance`, `price`, `total`) are serialized as strings for precision:
    - `"1000.00"`, `"75.99"`, etc.

### Error format

- Client errors follow:
  ```json
  {
    "error": "<error_code>",
    "message": "<human_readable_message>"
  }
  ```
  
- Common error codes:
    - `products_not_found`
    - `products_already_purchased`
    - `insufficient_balance`
    - `unauthenticated`
    - `internal_server_error`

### Legacy compatibility

- Legacy endpoints are available without authentication and return the original prototype shapes.
- They include an `X-Deprecated` header advising the modern alternative.
- Differences:
    - Legacy user: `{"user": {"user_id": "<username>", "data": {"balance": "...", "product_ids": []}}}`
    - Legacy order response nests data and uses `order_id`; modern uses `id` and flattens fields.