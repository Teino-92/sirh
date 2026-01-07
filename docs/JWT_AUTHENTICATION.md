# JWT Authentication Guide

## Overview

Easy-RH uses JWT (JSON Web Tokens) for API authentication, powered by the `devise-jwt` gem. This allows mobile apps and external clients to authenticate securely.

## Configuration

### Devise JWT Setup

JWT authentication is configured in `config/initializers/devise.rb`:

```ruby
config.jwt do |jwt|
  jwt.secret = ENV.fetch('JWT_SECRET_KEY', 'fallback-secret-key')
  jwt.dispatch_requests = [['POST', %r{^/api/v1/login$}]]
  jwt.revocation_requests = [['DELETE', %r{^/api/v1/logout$}]]
  jwt.expiration_time = 1.day.to_i
end
```

### Employee Model

The `Employee` model includes `:jwt_authenticatable`:

```ruby
devise :database_authenticatable, :registerable,
       :recoverable, :rememberable, :validatable,
       :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
```

### Token Revocation

Revoked tokens are stored in the `jwt_denylists` table via the `JwtDenylist` model.

## API Endpoints

### Login (Get JWT Token)

**Endpoint:** `POST /api/v1/login`

**Request:**
```bash
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@techcorp.fr",
    "password": "password123"
  }'
```

**Response:**
```json
{
  "message": "Logged in successfully",
  "employee": {
    "id": 1,
    "email": "admin@techcorp.fr",
    "first_name": "Admin",
    "last_name": "User",
    "role": "admin",
    "organization": {
      "id": 1,
      "name": "TechCorp"
    }
  }
}
```

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI...
```

The JWT token is returned in the `Authorization` header. Extract and store this token for subsequent API calls.

### Making Authenticated API Requests

Include the JWT token in the `Authorization` header:

```bash
curl http://localhost:3000/api/v1/me/dashboard \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -H "Content-Type: application/json"
```

### Logout (Revoke Token)

**Endpoint:** `DELETE /api/v1/logout`

```bash
curl -X DELETE http://localhost:3000/api/v1/logout \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE"
```

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

### Token Refresh (Renew Token)

**Endpoint:** `POST /api/v1/refresh`

Refresh your JWT token before it expires without re-authenticating.

**Request:**
```bash
curl -X POST http://localhost:3000/api/v1/refresh \
  -H "Authorization: Bearer YOUR_CURRENT_TOKEN" \
  -H "Content-Type: application/json"
```

**Response:**
```json
{
  "message": "Token refreshed successfully",
  "employee": {
    "id": 1,
    "email": "admin@techcorp.fr",
    "first_name": "Admin",
    "last_name": "User"
  }
}
```

**Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.NEW_TOKEN_HERE...
```

The new JWT token is returned in the `Authorization` header. Store this token and use it for subsequent requests.

**Best Practice:**
- Refresh token **before** it expires (e.g., when less than 30 minutes remaining)
- Implement automatic refresh in mobile apps to provide seamless UX
- Old token is automatically revoked when new token is issued

## Token Lifecycle

1. **Login**: Employee provides email/password → Server validates → JWT token issued in response header
2. **API Calls**: Client includes JWT token in `Authorization` header
3. **Validation**: Server validates token on each request
4. **Refresh**: Before expiration, call `/api/v1/refresh` to get new token
5. **Expiration**: Tokens expire after 1 day (configurable)
6. **Logout**: Token added to denylist table

## Security Notes

### Production Setup

**IMPORTANT:** In production, set a strong JWT secret key:

```bash
# Generate a secure random key
rails secret

# Set environment variable
export JWT_SECRET_KEY="your-super-secret-key-here"
```

### Token Storage (Mobile Apps)

- **iOS**: Use Keychain Services
- **Android**: Use EncryptedSharedPreferences
- **Never** store tokens in plain text or UserDefaults/SharedPreferences

### HTTPS Required

JWT tokens MUST be transmitted over HTTPS in production to prevent man-in-the-middle attacks.

### Rate Limiting

Easy-RH implements rate limiting via **Rack::Attack** to protect against abuse:

**Login Endpoint Protection:**
- **Per IP**: 5 login attempts per 20 seconds
- **Per Email**: 10 login attempts per 5 minutes (distributed attack protection)

**General API Limits:**
- **Unauthenticated**: 300 requests per 5 minutes per IP
- **Authenticated**: 100 requests per minute per user

**Rate Limit Headers:**
When throttled, you'll receive a `429 Too Many Requests` response with headers:
```
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1704123456
Retry-After: 20
```

**Example Response:**
```json
{
  "error": "Too many requests. Please try again later."
}
```

**Best Practices:**
- Monitor `X-RateLimit-Remaining` header to avoid hitting limits
- Implement exponential backoff when rate limited
- Cache responses when possible to reduce API calls
- Use token refresh instead of re-logging in

## Testing JWT Authentication

### With curl

```bash
# 1. Login and capture token
TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@techcorp.fr", "password": "password123"}' \
  -i | grep -i "^authorization:" | sed 's/Authorization: Bearer //' | tr -d '\r')

echo "Token: $TOKEN"

# 2. Use token for API call
curl http://localhost:3000/api/v1/me/dashboard \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# 3. Logout
curl -X DELETE http://localhost:3000/api/v1/logout \
  -H "Authorization: Bearer $TOKEN"
```

### Test Accounts (from seeds.rb)

```
HR Admin:
  Email: admin@techcorp.fr
  Password: password123

Manager:
  Email: thomas.martin@techcorp.fr
  Password: password123

Employee:
  Email: julien.petit@techcorp.fr
  Password: password123
```

## Mobile App Integration

### iOS (Swift)

```swift
// Login
struct LoginRequest: Codable {
    let email: String
    let password: String
}

func login(email: String, password: String) async throws -> String {
    let url = URL(string: "https://api.easy-rh.com/api/v1/login")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = LoginRequest(email: email, password: password)
    request.httpBody = try JSONEncoder().encode(body)

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          let token = httpResponse.value(forHTTPHeaderField: "Authorization") else {
        throw LoginError.noToken
    }

    // Store token in Keychain
    try KeychainHelper.save(token: token)

    return token.replacingOccurrences(of: "Bearer ", with: "")
}

// API Call with token
func fetchDashboard() async throws -> Dashboard {
    let url = URL(string: "https://api.easy-rh.com/api/v1/me/dashboard")!
    var request = URLRequest(url: url)

    let token = try KeychainHelper.getToken()
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(Dashboard.self, from: data)
}
```

### Android (Kotlin)

```kotlin
// Login
suspend fun login(email: String, password: String): String {
    val client = OkHttpClient()
    val json = JSONObject()
        .put("email", email)
        .put("password", password)

    val body = json.toString()
        .toRequestBody("application/json".toMediaType())

    val request = Request.Builder()
        .url("https://api.easy-rh.com/api/v1/login")
        .post(body)
        .build()

    val response = client.newCall(request).execute()
    val token = response.header("Authorization")
        ?.removePrefix("Bearer ")
        ?: throw Exception("No token received")

    // Store token in EncryptedSharedPreferences
    securePrefs.edit()
        .putString("jwt_token", token)
        .apply()

    return token
}

// API Call with token
suspend fun fetchDashboard(): Dashboard {
    val token = securePrefs.getString("jwt_token", null)
        ?: throw Exception("Not authenticated")

    val request = Request.Builder()
        .url("https://api.easy-rh.com/api/v1/me/dashboard")
        .header("Authorization", "Bearer $token")
        .build()

    val response = client.newCall(request).execute()
    return gson.fromJson(response.body?.string(), Dashboard::class.java)
}
```

## Troubleshooting

### "Signature verification failed"
- JWT secret key mismatch between environments
- Check `JWT_SECRET_KEY` environment variable

### "Token has expired"
- Tokens expire after 1 day
- Re-authenticate to get a new token

### "Revoked token"
- Token was explicitly revoked (logout)
- Check `jwt_denylists` table

### No Authorization header in response
- Ensure request matches dispatch pattern: `POST /api/v1/login`
- Check `config/initializers/devise.rb` configuration

## Database Tables

### jwt_denylists
Stores revoked tokens to prevent reuse after logout.

```sql
CREATE TABLE jwt_denylists (
  id bigint PRIMARY KEY,
  jti string NOT NULL,
  exp datetime NOT NULL
);

CREATE INDEX index_jwt_denylists_on_jti ON jwt_denylists(jti);
```

## References

- [devise-jwt gem](https://github.com/waiting-for-dev/devise-jwt)
- [JWT.io](https://jwt.io/)
- [RFC 7519 - JWT Standard](https://tools.ietf.org/html/rfc7519)
