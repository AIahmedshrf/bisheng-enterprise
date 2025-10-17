
---

## 📄 الملف 31: `docs/API.md`

```markdown
# 📡 Bisheng Enterprise API Documentation

## نظرة عامة

Bisheng Enterprise يوفر RESTful API شامل للتفاعل مع النظام.

**Base URL:** `https://your-domain.com/api/v1`

**Authentication:** Bearer Token (JWT)

---

## 🔐 المصادقة (Authentication)

### الحصول على Token

**Endpoint:** `POST /auth/login`

**Request:**
```json
{
  "email": "admin@bisheng.io",
  "password": "your-password"
}

Response:

JSON

{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}

مثال باستخدام curl:

Bash

curl -X POST https://your-domain.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@bisheng.io","password":"your-password"}'

تجديد Token

Endpoint: POST /auth/refresh

Request:

JSON

{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}

📄 إدارة الوثائق
1. رفع وثيقة

Endpoint: POST /documents/upload

Headers:

text

Authorization: Bearer YOUR_TOKEN
Content-Type: multipart/form-data

Request (Form Data):

text

file: [binary file]
collection: "research"
metadata: {"author": "John Doe", "year": 2024}
extract_tables: true
extract_images: true
ocr: true
language: "ara"

Response:

JSON

{
  "id": "doc_abc123",
  "filename": "research-paper.pdf",
  "collection": "research",
  "status": "processing",
  "pages": 45,
  "size_bytes": 2048576,
  "created_at": "2024-01-15T10:30:00Z",
  "metadata": {
    "author": "John Doe",
    "year": 2024
  }
}

مثال:

Bash

curl -X POST https://your-domain.com/api/v1/documents/upload \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@research-paper.pdf" \
  -F "collection=research" \
  -F "extract_tables=true" \
  -F "ocr=true" \
  -F "language=ara"

Python:

Python

import requests

url = "https://your-domain.com/api/v1/documents/upload"
headers = {"Authorization": "Bearer YOUR_TOKEN"}
files = {"file": open("research-paper.pdf", "rb")}
data = {
    "collection": "research",
    "extract_tables": "true",
    "ocr": "true",
    "language": "ara"
}

response = requests.post(url, headers=headers, files=files, data=data)
print(response.json())

2. الحصول على حالة الوثيقة

Endpoint: GET /documents/{document_id}

Response:

JSON

{
  "id": "doc_abc123",
  "filename": "research-paper.pdf",
  "status": "completed",
  "progress": 100,
  "pages": 45,
  "text_extracted": true,
  "tables_count": 12,
  "images_count": 8,
  "embeddings_generated": true,
  "processing_time_seconds": 45.2,
  "created_at": "2024-01-15T10:30:00Z",
  "completed_at": "2024-01-15T10:30:45Z"
}

3. قائمة الوثائق

Endpoint: GET /documents

Query Parameters:

text

collection: string (optional)
status: string (optional) - "processing", "completed", "failed"
page: integer (default: 1)
page_size: integer (default: 20, max: 100)
sort_by: string (default: "created_at")
order: string (default: "desc") - "asc", "desc"

Response:

JSON

{
  "total": 150,
  "page": 1,
  "page_size": 20,
  "total_pages": 8,
  "documents": [
    {
      "id": "doc_abc123",
      "filename": "research-paper.pdf",
      "collection": "research",
      "status": "completed",
      "pages": 45,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ]
}

4. حذف وثيقة

Endpoint: DELETE /documents/{document_id}

Response:

JSON

{
  "message": "Document deleted successfully",
  "id": "doc_abc123"
}

🔍 البحث
1. البحث النصي (Full-text Search)

Endpoint: POST /search/text

Request:

JSON

{
  "query": "الذكاء الاصطناعي في التعليم",
  "collection": "research",
  "filters": {
    "year": {"gte": 2020},
    "author": "John Doe"
  },
  "limit": 10,
  "offset": 0,
  "highlight": true
}

Response:

JSON

{
  "total": 45,
  "results": [
    {
      "document_id": "doc_abc123",
      "score": 0.95,
      "filename": "ai-education.pdf",
      "page": 3,
      "snippet": "...الذكاء <em>الاصطناعي</em> يلعب دوراً مهماً في <em>التعليم</em>...",
      "metadata": {
        "author": "John Doe",
        "year": 2023
      }
    }
  ],
  "took_ms": 45
}

2. البحث الدلالي (Semantic Search)

Endpoint: POST /search/semantic

Request:

JSON

{
  "query": "applications of AI in education",
  "collection": "research",
  "similarity_threshold": 0.7,
  "limit": 10,
  "rerank": true
}

Response:

JSON

{
  "total": 28,
  "results": [
    {
      "document_id": "doc_abc123",
      "similarity": 0.89,
      "filename": "ai-education.pdf",
      "page": 5,
      "text": "Artificial intelligence applications in modern education...",
      "metadata": {}
    }
  ],
  "took_ms": 120
}

3. البحث المختلط (Hybrid Search)

Endpoint: POST /search/hybrid

Request:

JSON

{
  "query": "machine learning algorithms",
  "collection": "research",
  "text_weight": 0.3,
  "semantic_weight": 0.7,
  "limit": 10
}

💬 الدردشة مع الذكاء الاصطناعي
1. سؤال وجواب

Endpoint: POST /chat/ask

Request:

JSON

{
  "question": "ما هي فوائد الذكاء الاصطناعي في التعليم؟",
  "collection": "research",
  "model": "gpt-4",
  "temperature": 0.7,
  "max_tokens": 500,
  "stream": false,
  "include_sources": true
}

Response:

JSON

{
  "answer": "الذكاء الاصطناعي يوفر عدة فوائد في التعليم منها:\n1. التعلم المخصص...",
  "model": "gpt-4",
  "sources": [
    {
      "document_id": "doc_abc123",
      "filename": "ai-education.pdf",
      "page": 12,
      "relevance": 0.92
    }
  ],
  "tokens_used": 320,
  "took_ms": 1500
}

Streaming Response:

JSON

// مع stream: true
{"type": "token", "content": "الذكاء"}
{"type": "token", "content": " الاصطناعي"}
{"type": "token", "content": " يوفر"}
...
{"type": "done", "sources": [...]}

2. محادثة متعددة الأدوار

Endpoint: POST /chat/conversation

Request:

JSON

{
  "conversation_id": "conv_xyz789",
  "message": "أخبرني المزيد عن التعلم المخصص",
  "collection": "research",
  "model": "gpt-4"
}

📊 التحليلات والاستخراج
1. استخراج النص

Endpoint: GET /documents/{document_id}/text

Query Parameters:

text

pages: string (optional) - "1,2,3" or "1-5"
format: string (default: "plain") - "plain", "markdown", "html"

Response:

JSON

{
  "document_id": "doc_abc123",
  "pages": [
    {
      "page_number": 1,
      "text": "Full text content...",
      "word_count": 450
    }
  ],
  "total_words": 12500
}

2. استخراج الجداول

Endpoint: GET /documents/{document_id}/tables

Response:

JSON

{
  "document_id": "doc_abc123",
  "tables": [
    {
      "page": 5,
      "table_index": 0,
      "rows": 10,
      "columns": 4,
      "data": [
        ["Header 1", "Header 2", "Header 3", "Header 4"],
        ["Row 1 Col 1", "Row 1 Col 2", "Row 1 Col 3", "Row 1 Col 4"]
      ],
      "format": "csv"
    }
  ]
}

3. استخراج الصور

Endpoint: GET /documents/{document_id}/images

Response:

JSON

{
  "document_id": "doc_abc123",
  "images": [
    {
      "page": 3,
      "image_index": 0,
      "width": 800,
      "height": 600,
      "format": "png",
      "url": "https://your-domain.com/api/v1/documents/doc_abc123/images/0",
      "thumbnail_url": "https://your-domain.com/api/v1/documents/doc_abc123/images/0/thumbnail"
    }
  ]
}

4. تلخيص

Endpoint: POST /documents/{document_id}/summarize

Request:

JSON

{
  "model": "gpt-4",
  "max_length": 500,
  "language": "ar",
  "style": "academic"
}

Response:

JSON

{
  "summary": "هذا البحث يناقش...",
  "word_count": 150,
  "original_word_count": 12500,
  "compression_ratio": 0.012
}

5. ترجمة

Endpoint: POST /translate

Request:

JSON

{
  "text": "Artificial intelligence in education",
  "source_language": "en",
  "target_language": "ar",
  "model": "gpt-4"
}

Response:

JSON

{
  "translated_text": "الذكاء الاصطناعي في التعليم",
  "source_language": "en",
  "target_language": "ar",
  "confidence": 0.95
}

📁 إدارة المجموعات
1. إنشاء مجموعة

Endpoint: POST /collections

Request:

JSON

{
  "name": "research-2024",
  "description": "Research papers from 2024",
  "embedding_model": "text-embedding-ada-002",
  "metadata": {
    "department": "AI Research"
  }
}

2. قائمة المجموعات

Endpoint: GET /collections

Response:

JSON

{
  "collections": [
    {
      "id": "coll_123",
      "name": "research-2024",
      "document_count": 150,
      "total_size_bytes": 524288000,
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}

👥 إدارة المستخدمين (Admin فقط)
1. إنشاء مستخدم

Endpoint: POST /admin/users

Request:

JSON

{
  "email": "user@example.com",
  "password": "secure-password",
  "role": "researcher",
  "permissions": ["read", "search", "upload"]
}

2. قائمة المستخدمين

Endpoint: GET /admin/users
📈 الإحصائيات والمقاييس
1. إحصائيات النظام

Endpoint: GET /stats/system

Response:

JSON

{
  "documents": {
    "total": 1500,
    "processing": 5,
    "completed": 1490,
    "failed": 5
  },
  "storage": {
    "total_bytes": 10737418240,
    "documents_bytes": 8589934592,
    "embeddings_bytes": 2147483648
  },
  "usage": {
    "api_calls_today": 15000,
    "searches_today": 5000,
    "uploads_today": 50
  }
}

2. إحصائيات الاستخدام

Endpoint: GET /stats/usage

Query Parameters:

text

start_date: string (ISO 8601)
end_date: string (ISO 8601)
granularity: string - "hour", "day", "week", "month"

🔔 Webhooks
تكوين Webhook

Endpoint: POST /webhooks

Request:

JSON

{
  "url": "https://your-app.com/webhook",
  "events": ["document.completed", "document.failed"],
  "secret": "your-webhook-secret"
}

Webhook Payload Example:

JSON

{
  "event": "document.completed",
  "timestamp": "2024-01-15T10:30:45Z",
  "data": {
    "document_id": "doc_abc123",
    "filename": "research-paper.pdf",
    "status": "completed"
  },
  "signature": "sha256=..."
}

⚠️ معالجة الأخطاء
رموز الحالة
Code	المعنى
200	Success
201	Created
400	Bad Request
401	Unauthorized
403	Forbidden
404	Not Found
429	Too Many Requests
500	Internal Server Error
صيغة الخطأ

JSON

{
  "error": {
    "code": "DOCUMENT_NOT_FOUND",
    "message": "Document with ID 'doc_abc123' not found",
    "details": {
      "document_id": "doc_abc123"
    },
    "timestamp": "2024-01-15T10:30:00Z",
    "request_id": "req_xyz789"
  }
}

🚦 Rate Limiting

الحدود الافتراضية:

    100 requests/minute للمستخدمين العاديين
    1000 requests/minute للحسابات المميزة
    10 uploads/minute

Headers:

text

X-RateLimit-Limit: 100
X-RateLimit-Remaining: 75
X-RateLimit-Reset: 1642253400

📚 أمثلة كاملة
Python SDK

انظر python-sdk.md
JavaScript/TypeScript

JavaScript

// قريباً

cURL Examples

Bash

# رفع وثيقة
curl -X POST https://your-domain.com/api/v1/documents/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@document.pdf" \
  -F "collection=research"

# بحث
curl -X POST https://your-domain.com/api/v1/search/text \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"AI in education","collection":"research","limit":10}'

# سؤال وجواب
curl -X POST https://your-domain.com/api/v1/chat/ask \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"question":"What is AI?","collection":"research","model":"gpt-4"}'

📖 المراجع

    Postman Collection
    OpenAPI Specification
    Swagger UI
