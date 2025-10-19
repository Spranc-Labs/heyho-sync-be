# 📚 HeyHo Sync API - Postman Collections

Complete API testing collections for the HeyHo Sync backend with **JWT Authentication System**.

## 📋 Available Collections

### 🆕 **JWT Authentication Collection (Recommended)**
- **File**: `HeyHo_Sync_JWT_Auth_Complete.postman_collection.json`
- **Description**: **Complete JWT-based authentication with 6-digit email verification**
- **Features**:
  - ✅ **JWT Tokens** (AccessToken, IdToken, RefreshToken)
  - ✅ **6-Digit Email Verification** (simple codes instead of complex tokens)
  - ✅ **Auto Token Management** (saves/loads tokens automatically)
  - ✅ **Production-Ready Format** (matches AWS Cognito style responses)
  - ✅ **Comprehensive Testing** (all success/failure scenarios)
  - ✅ **Real Response Examples** (from actual API responses)

### 🌍 **Environment**
- **File**: `HeyHo_Sync_Environment.postman_environment.json`
- **Description**: Development environment variables
- **Variables**: Auto-managed by JWT collection

### 📦 **Legacy Collections** (Old System)
- `HeyHo_Sync_Complete_API_Collection.json` - Legacy session-based auth
- `HeyHo_Sync_Rodauth_Collection.json` - Original Rodauth collection
- `HeyHo_Sync_Auth_Collection.json` - Legacy Devise collection

> **⚠️ Important**: Use the **JWT Authentication Collection** for current development. Legacy collections are for reference only.

---

## 🔧 **Quick Setup**

### 1. Import Collections
1. Open Postman
2. Click **Import**
3. Select these files:
   - `HeyHo_Sync_Complete_API_Collection.postman_collection.json`
   - `HeyHo_Sync_Environment.postman_environment.json`

### 2. Set Environment
1. Select **"HeyHo Sync - Development Environment"** from environment dropdown
2. Verify `base_url` is set to `http://localhost:3000`

### 3. Start Testing (JWT System)
1. Start your Rails server: `docker-compose up app`
2. Follow JWT auth flow: **Create Account** → **Verify Email** → **Login** → **Authenticated Endpoints**

---

## 📖 **API Endpoints Overview (JWT System)**

### 🔐 **JWT Authentication**
| Method | Endpoint | Description | Response Format |
|--------|----------|-------------|-----------------|
| `POST` | `/api/v1/create-account` | Register user + get 6-digit code | `{success, verification_code, user}` |
| `POST` | `/api/v1/verify-email` | Verify with email + 6-digit code | `{success, message}` |
| `POST` | `/api/v1/resend-verification` | Get new 6-digit code | `{success, data: {verification_code}}` |
| `POST` | `/api/v1/login` | Login → get JWT tokens | `{statusCode, data: {AccessToken, IdToken, RefreshToken}}` |
| `POST` | `/api/v1/logout` | Invalidate session | `{statusCode, message, error}` |

### 🔒 **Protected Endpoints** (Require `Authorization: Bearer <AccessToken>`)
| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| `GET` | `/api/v1/users/me` | Get current user profile | ✅ JWT |

### 🔑 **Password Management**
| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| `POST` | `/api/v1/reset-password-request` | Request password reset | ❌ |
| `POST` | `/api/v1/reset-password` | Complete password reset | ❌ |
| `POST` | `/api/v1/change-password` | Change password | ✅ |

### 📝 **Account Management**
| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| `POST` | `/api/v1/change-login` | Request email change | ✅ |
| `POST` | `/api/v1/verify-login-change` | Confirm email change | ❌ |
| `POST` | `/api/v1/close-account` | Close/deactivate account | ✅ |

### 👤 **User Profile**
| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| `GET` | `/api/v1/users/me` | Get current user profile | ✅ |
| `PATCH` | `/api/v1/users/me` | Update user profile | ✅ |

### 🏥 **System**
| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| `GET` | `/` | API root/health check | ❌ |

---

## 💡 **Smart Features**

### 🔄 **Auto Token Management**
- **Login/Signup**: Automatically saves `access_token` to environment
- **Authenticated Requests**: Use `{{access_token}}` variable
- **No Manual Token Copying**: Seamless workflow

### 📝 **Comprehensive Examples**
Each endpoint includes:
- ✅ **Success Response** - Valid request with expected response
- ❌ **Error Responses** - Invalid data, validation errors, auth failures
- 📋 **Proper Request Bodies** - Correctly formatted JSON with all required fields
- 🔍 **Detailed Descriptions** - Clear explanation of each endpoint's purpose

### 🛠️ **Pre/Post Scripts**
- **Pre-request**: Auto-sets `base_url` if missing
- **Post-response**: Logs responses for debugging
- **Token Capture**: Automatically extracts and saves JWT tokens

---

## 📊 **JWT Authentication Flow Examples**

### 🔐 **1. User Registration (Get 6-Digit Code)**

**Request:**
```http
POST /api/v1/create-account
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Account created successfully. Please verify your email.",
  "verification_code": "123456",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "status": "unverified"
  }
}
```

### 📧 **2. Email Verification (Use 6-Digit Code)**

**Request:**
```http
POST /api/v1/verify-email
Content-Type: application/json

{
  "email": "user@example.com",
  "code": "123456"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Email verified successfully"
}
```

### 🔑 **3. Login (Get JWT Tokens)**

**Request:**
```http
POST /api/v1/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Success Response (200) - JWT Tokens:**
```json
{
  "statusCode": 200,
  "message": "User logged in successfully",
  "error": false,
  "data": {
    "AccessToken": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOjEsImlzcyI6ImhleWhvLXN5bmMtYXBpIiwiYXVkIjoiaGV5aG8tc3luYy1hcHAiLCJpYXQiOjE3NTgzNjk4MDMsImV4cCI6MTc1ODM3MzQwMywic2NvcGUiOiJ1c2VyIn0.example",
    "ExpiresIn": 3600,
    "IdToken": "eyJhbGciOiJIUzI1NiJ9.eyJ0eXBlIjoiaWRUb2tlbiIsImRhdGEiOnsidXNlciI6eyJmaXJzdE5hbWUiOiJKb2huIiwibGFzdE5hbWUiOiJEb2UiLCJ1c2VySWQiOiJ1c2VyXzEiLCJlbWFpbCI6InVzZXJAZXhhbXBsZS5jb20iLCJ0aXRsZSI6IiIsInByb2ZpbGVVcmwiOiIiLCJwaG9uZSI6IiIsIm9yZ2FuaXphdGlvbiI6IiIsImNvdW50cnkiOiIifX0sImlhdCI6MTc1ODM2OTgwMywiZXhwIjoxNzU4MzczNDAzfQ.example",
    "RefreshToken": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJpYXQiOjE3NTgzNjk4MDMsImV4cCI6MTc2MDk2MTgwM30.example",
    "TokenType": "Bearer"
  }
}
```

### 🔒 **4. Authenticated Request (Use AccessToken)**

**Request:**
```http
GET /api/v1/users/me
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOjEsImlzcyI6ImhleWhvLXN5bmMtYXBpIi...
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "status": "verified",
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    }
  }
}
```

### ❌ **Common Error Responses**

**Invalid Credentials (401):**
```json
{
  "error": "There was an error logging in"
}
```

**Email Already Exists (422):**
```json
{
  "field-error": ["email", "already an account with this email address"],
  "error": "There was an error creating your account"
}
```

**Invalid Verification Code (422):**
```json
{
  "success": false,
  "message": "Invalid or expired verification code"
}
```

**Unauthorized Access (401):**
```json
{
  "success": false,
  "message": "You need to sign in or sign up before continuing."
}
```

### 👤 **Protected Endpoint Example**

**Request:**
```http
GET /api/v1/users/me
Authorization: Bearer {{access_token}}
```

**Success Response (200):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 1,
      "email": "user@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "status": "verified",
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    }
  }
}
```

---

## 🧪 **Testing Scenarios**

### ✅ **Happy Path Testing**
1. **Create Account** → Get access token
2. **Verify Account** → Account becomes verified
3. **Login** → Get new access token
4. **Get Profile** → View user data
5. **Update Profile** → Modify user info
6. **Change Password** → Update credentials
7. **Logout** → Invalidate token

### ❌ **Error Scenario Testing**
1. **Validation Errors** - Missing fields, invalid email format
2. **Authentication Errors** - Wrong password, expired tokens
3. **Authorization Errors** - Accessing protected endpoints without token
4. **Business Logic Errors** - Email already taken, account already verified
5. **Rate Limiting** - Too many requests (if implemented)

### 🔒 **Security Testing**
1. **Token Validation** - Invalid/expired/malformed tokens
2. **Password Security** - Weak passwords, password mismatch
3. **Email Enumeration** - Non-existent email handling
4. **Account States** - Unverified account restrictions

---

## 🔧 **Environment Variables**

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `base_url` | API server URL | `http://localhost:3000` |
| `access_token` | JWT token (auto-set) | `""` |
| `test_email` | Test email address | `user@example.com` |
| `test_password` | Test password | `SecurePass123!` |
| `test_first_name` | Test first name | `John` |
| `test_last_name` | Test last name | `Doe` |

### 🌐 **Different Environments**
You can create additional environments for:
- **Production**: `https://api.yourdomain.com`
- **Staging**: `https://staging-api.yourdomain.com`
- **Local Development**: `http://localhost:3000`

---

## 🐛 **Troubleshooting**

### 🔴 **Common Issues**

#### **Connection Refused**
```
Error: connect ECONNREFUSED 127.0.0.1:3000
```
**Solution**: Ensure Rails server is running: `docker-compose up app`

#### **401 Unauthorized**
```json
{"error": "Please login to continue"}
```
**Solution**:
1. Login first to get access token
2. Check `{{access_token}}` variable is set
3. Verify token hasn't expired

#### **422 Validation Error**
```json
{"field-error": ["email", "already an account with this email address"]}
```
**Solution**: Use different email or check existing accounts

#### **500 Internal Server Error**
**Solutions**:
1. Check Rails logs: `docker-compose logs app`
2. Verify database is running: `docker-compose ps`
3. Check for missing environment variables

### 🔍 **Debugging Tips**

1. **Enable Console Logs**: Check Postman console for detailed logs
2. **Check Environment**: Verify correct environment is selected
3. **Inspect Responses**: Use Postman's response viewer
4. **Test Manually**: Use curl to isolate issues
5. **Check Server Logs**: Monitor Rails application logs

---

## 📈 **Best Practices**

### 🎯 **Testing Workflow**
1. **Start Fresh**: Clear environment variables between test sessions
2. **Sequential Testing**: Follow logical order (signup → verify → login)
3. **Use Different Emails**: Avoid conflicts with existing accounts
4. **Check All Scenarios**: Test both success and failure cases
5. **Monitor Logs**: Watch server logs for detailed error information

### 🔐 **Security Best Practices**
1. **Token Management**: Never commit real tokens to version control
2. **Test Data**: Use fake/test data only
3. **Environment Separation**: Use different credentials per environment
4. **Token Rotation**: Regularly refresh tokens in long testing sessions

### 🚀 **Performance Testing**
1. **Response Times**: Monitor API response times
2. **Rate Limiting**: Test rate limit boundaries
3. **Concurrent Requests**: Test multiple simultaneous requests
4. **Load Testing**: Use Postman's performance features

---

## 📚 **Additional Resources**

- **API Documentation**: See `/docs/api/` for detailed endpoint documentation
- **Rodauth Docs**: [rodauth.jeremyevans.net](http://rodauth.jeremyevans.net/)
- **Postman Learning**: [learning.postman.com](https://learning.postman.com/)
- **JWT.io**: [jwt.io](https://jwt.io/) for token debugging

---

## ✅ **Checklist for New Team Members**

- [ ] Import Postman collections and environment
- [ ] Start local development server
- [ ] Test basic signup/login flow
- [ ] Verify token auto-capture works
- [ ] Test at least one protected endpoint
- [ ] Review error response examples
- [ ] Check environment variables are set correctly
- [ ] Bookmark this README for reference

---

**Happy Testing! 🚀**

*This collection provides comprehensive API testing capabilities for the HeyHo Sync backend. For questions or issues, refer to the main project documentation.*