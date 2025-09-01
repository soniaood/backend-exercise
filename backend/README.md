# Benefits Management Backend API

A Phoenix/Elixir backend API for an application providing user register and authentication, product (benefits) fetching, and order (benefit purchases) management capabilities. It could be iterated upon further.

## The Challenge

The challenge required building an API for an existing React frontend prototype with these specifications:

**Requirements:**
- Retrieve data from a single user (indexed by username)
- Retrieve a collection of products (with unique ID, price, name)
- Place orders with balance validation and duplicate purchase prevention
- Support these endpoints:
  - `GET /api/users/:user_id` - Returns/creates user
  - `GET /api/products` - Returns product list
  - `POST /api/orders` - Creates orders

**Limitations:**
- **No authentication** - any user could access any data
- **Username-based identification** - insecure and inflexible
- **Limited error handling** - basic success/failure responses
- **Inconsistent data formats** - product names used as IDs
- **REST inconsistency** - GET endpoints used for creating data

## Entities and API Design
### Data Model

#### Entities
- **User**: Account with balance and authentication credentials
- **Product**: Benefit with pricing (Netflix, Spotify, etc.)
- **Order**: Purchase transaction with total amount
- **OrderItem**: Individual item within an order
- **UserProduct**: Ownership product tracking

```mermaid
erDiagram
    User ||--o{ Order : places
    User ||--o{ UserProduct : owns
    Order ||--o{ OrderItem : contains
    Product ||--o{ OrderItem : referenced_in
    Product ||--o{ UserProduct : owned_via

    User {
        uuid id PK
        string username UK
        string email UK
        string password_hash
        decimal balance
        datetime inserted_at
        datetime updated_at
    }

    Product {
        uuid id PK
        string name UK
        string description
        decimal price
        datetime inserted_at
        datetime updated_at
    }

    Order {
        uuid id PK
        uuid user_id FK
        decimal total
        datetime inserted_at
        datetime updated_at
    }

    OrderItem {
        uuid id PK
        uuid order_id FK
        uuid product_id FK
        decimal price
        datetime inserted_at
        datetime updated_at
    }

    UserProduct {
        uuid id PK
        uuid user_id FK
        uuid product_id FK
        uuid order_id FK
        datetime inserted_at
        datetime updated_at
    }
```

### Upgraded API Version

This API addresses the limitations while still maintaining backwards compatibility for the Frontend prototype.

#### API Overview

```mermaid
graph LR
    Frontend[React Frontend<br/>Prototype] -->|/api/*| Legacy[Legacy API<br/>Compatible]
    NewClient[New Client] -->|/api/v1/*| Enhanced[Enhanced API<br/>JWT Auth]
    
    Legacy --> Controllers[Controllers Layer<br/>- UserController<br/>- ProductController<br/>- OrderController<br/>- AuthController]
    Enhanced --> Controllers
    Controllers --> Contexts[Business Logic<br/>- Backend.Users<br/>- Backend.Products<br/>- Backend.Orders]
    Contexts --> DB[(PostgreSQL<br/>Database)]
    
    style Legacy fill:#ffeb3b
    style Enhanced fill:#4caf50
    style Contexts fill:#2196f3
```

#### Frontend Prototype API (`/api/*`)
```
GET /api/users/john_doe          # No auth required, creates user if missing
GET /api/products                # Returns products with names as IDs  
POST /api/orders                 # Uses product names, not UUIDs
```

<details>
<summary>Response Examples</summary>

```json
// GET /api/users/john_doe
{
  "user": {
    "user_id": "johndoe",
    "data": {
      "balance": "1000.00",
      "product_ids": ["netflix"]
    }
  }
}

// GET /api/products  
{
  "products": [
    {
      "id": "netflix",
      "name": "Netflix Premium",
      "price": "15.99"
    }
  ]
}

// POST /api/orders
{
  "order": {
    "order_id": "550e8400-e29b-41d4-a716-446655440000",
    "data": {
      "items": [
        {
          "id": "netflix",
          "name": "Netflix Premium",
          "price": "15.99"
        }
      ],
      "total": "15.99"
    }
  }
}
```
</details>

#### New Endpoints (`/api/v1/*`)
```
POST /api/v1/auth/register       # User registration
POST /api/v1/auth/login          # JWT authentication
GET /api/v1/products             # UUID-based products
GET /api/v1/users/me             # User fetching
POST /api/v1/orders              # Authenticated orders
```

<details>
<summary>Response Examples</summary>

```json
// POST /api/v1/auth/register
{
  "username": "john_doe",
  "email": "john@example.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}

// POST /api/v1/auth/login  
{
  "username": "john_doe",
  "email": "john@example.com", 
  "balance": "1000.00",
  "product_ids": [],
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}

// GET /api/v1/products
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "netflix",
    "description": "Netflix Premium",
    "price": "15.99"
  }
]

// GET /api/v1/users/me
{
  "username": "john_doe",
  "email": "john@example.com",
  "balance": "984.01",
  "product_ids": ["550e8400-e29b-41d4-a716-446655440000"]
}

// POST /api/v1/orders
{
  "id": "550e8400-e29b-41d4-a716-446655440002",
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "netflix",
      "description": "Netflix Premium",
      "price": "15.99"
    }
  ],
  "total": "15.99",
  "created_at": "2024-01-15T10:30:00.000000Z"
}
```
</details>

## Development Setup

### Requirements
- **Elixir** 1.15+
- **Erlang/OTP** 26+
- **PostgreSQL** 13+
- **Docker** (for development)

### Running the Application
```bash
cd backend

# Database setup (PostgreSQL via Docker)
docker-compose up -d

# Install dependencies and setup database with migrations and seeds
mix setup

# Start Phoenix server
mix phx.server
```

The API will be available at:
- **Legacy**: `http://localhost:4000/api/*` (for existing frontend)
- **Enhanced**: `http://localhost:4000/api/v1/*` (for new applications)

### Testing
```bash
# Run all tests
mix test
```

### HTTP File Testing
For manual API testing, use the provided HTTP file `api_test.http`:

```bash
# 1. User registration
# 2. User login  
# 3. Product listing
# 4. User profile fetching
# 5. Order creation
# 6. Token refresh
# 7. User logout
```

## Key Assumptions

**Business Logic**
- Single currency (EUR) with 2 decimal precision for financial accuracy
- One-time purchases only - users can't buy the same product twice
- Static product catalog - products are seeded, not dynamically created yet
- All products are available for purchase by all users
- Default user balance of €1000.00 virtual currency for new accounts

**Legacy Compatibility**
- Support existing React frontend:
    - Username-based user identification
    - Product names (like "netflix") used as identifiers
    - No breaking changes to existing endpoint contracts

## Core Features

- **Authentication**: Prototype (open access) + V1 API (JWT with bcrypt)
- **Atomic Transactions**: All-or-nothing order processing with automatic rollback
- **Balance & Ownership Validation**: Prevents overdrafts and duplicate purchases
- **UUID Keys & Decimal Precision**: Security and accurate financial calculations

## Transaction Safety

The atomic order processing uses `Ecto.Multi` to ensure data consistency:

```mermaid
sequenceDiagram
    participant Client
    participant OrderController
    participant BackendOrders as Backend.Orders
    participant Database
    
    Client->>OrderController: POST /api/v1/orders
    OrderController->>BackendOrders: create_order(user_id, product_ids)
    
    BackendOrders->>Database: BEGIN TRANSACTION
    BackendOrders->>BackendOrders: 1. validate_input
    BackendOrders->>Database: 2. user (fetch with products)
    BackendOrders->>Database: 3. products (validate exist)
    BackendOrders->>BackendOrders: 4. validate_products (check user existing products)
    BackendOrders->>BackendOrders: 5. validate_balance (sufficient funds)
    BackendOrders->>Database: 6. order (create record)
    BackendOrders->>Database: 7. order_items (insert items)
    BackendOrders->>Database: 8. user_products (record user products)
    BackendOrders->>Database: 9. update_balance (deduct funds)
    BackendOrders->>Database: COMMIT TRANSACTION
    
    BackendOrders-->>OrderController: {:ok, order_data}
    OrderController-->>Client: 200 OK with order details
    
    Note over BackendOrders,Database: If any step fails, entire transaction rolls back
```

This multi-step transaction ensures that either all operations succeed or none do - preventing partial orders or inconsistent balances.

