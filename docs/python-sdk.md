# 🚀 الملفات الختامية - Python SDK & Development
📄 الملف 32: `docs/python-sdk.md`

---

# 🐍 Bisheng Enterprise Python SDK

## التثبيت

```bash
pip install bisheng-enterprise-sdk
```

أو من المصدر:

```bash
git clone https://github.com/yourusername/bisheng-python-sdk.git
cd bisheng-python-sdk
pip install -e .
```

---

🚀 البدء السريع

Python

from bisheng import BishengClient

# إنشاء العميل
client = BishengClient(
    api_url="https://your-domain.com/api/v1",
    api_key="your-api-key"
)

# رفع وثيقة
document = client.documents.upload(
    file_path="research-paper.pdf",
    collection="research",
    extract_tables=True,
    ocr=True,
    language="ara"
)

print(f"Document uploaded: {document.id}")

# البحث
results = client.search.text(
    query="الذكاء الاصطناعي",
    collection="research",
    limit=10
)

for result in results:
    print(f"- {result.filename} (score: {result.score})")

# سؤال وجواب
answer = client.chat.ask(
    question="ما هي تطبيقات الذكاء الاصطناعي؟",
    collection="research",
    model="gpt-4"
)

print(f"Answer: {answer.text}")

📚 الدليل الشامل
1. التهيئة والمصادقة
التهيئة الأساسية

Python

from bisheng import BishengClient

# باستخدام API Key
client = BishengClient(
    api_url="https://your-domain.com/api/v1",
    api_key="your-api-key"
)

# باستخدام البريد الإلكتروني وكلمة المرور
client = BishengClient(
    api_url="https://your-domain.com/api/v1",
    email="admin@bisheng.io",
    password="your-password"
)

# مع إعدادات إضافية
client = BishengClient(
    api_url="https://your-domain.com/api/v1",
    api_key="your-api-key",
    timeout=60,  # ثواني
    verify_ssl=True,
    max_retries=3
)

تجديد Token تلقائياً

Python

client = BishengClient(
    api_url="https://your-domain.com/api/v1",
    email="admin@bisheng.io",
    password="your-password",
    auto_refresh_token=True  # تجديد تلقائي
)

2. إدارة الوثائق
رفع وثيقة واحدة

Python

# رفع بسيط
document = client.documents.upload("paper.pdf")

# رفع مع خيارات متقدمة
document = client.documents.upload(
    file_path="research-paper.pdf",
    collection="research-2024",
    metadata={
        "author": "Dr. Ahmed",
        "year": 2024,
        "department": "AI Research",
        "tags": ["machine-learning", "nlp", "arabic"]
    },
    extract_tables=True,
    extract_images=True,
    ocr=True,
    language="ara",
    chunk_size=1000,
    chunk_overlap=200
)

print(f"Document ID: {document.id}")
print(f"Status: {document.status}")
print(f"Pages: {document.pages}")

رفع مجموعة من الوثائق

Python

import os
from pathlib import Path

# رفع كل ملفات PDF في مجلد
pdf_files = Path("./documents").glob("*.pdf")

uploaded = []
for pdf_file in pdf_files:
    try:
        doc = client.documents.upload(
            file_path=str(pdf_file),
            collection="research-2024"
        )
        uploaded.append(doc)
        print(f"✓ Uploaded: {pdf_file.name}")
    except Exception as e:
        print(f"✗ Failed: {pdf_file.name} - {e}")

print(f"\nTotal uploaded: {len(uploaded)}")

رفع بالتوازي (Parallel Upload)

Python

from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

def upload_file(file_path):
    """رفع ملف واحد"""
    try:
        doc = client.documents.upload(
            file_path=str(file_path),
            collection="research-2024"
        )
        return {"success": True, "file": file_path.name, "doc": doc}
    except Exception as e:
        return {"success": False, "file": file_path.name, "error": str(e)}

# جمع الملفات
pdf_files = list(Path("./documents").glob("*.pdf"))

# رفع بالتوازي (5 ملفات في نفس الوقت)
with ThreadPoolExecutor(max_workers=5) as executor:
    futures = [executor.submit(upload_file, f) for f in pdf_files]
    
    for future in as_completed(futures):
        result = future.result()
        if result["success"]:
            print(f"✓ {result['file']} - ID: {result['doc'].id}")
        else:
            print(f"✗ {result['file']} - Error: {result['error']}")

مراقبة تقدم الرفع

Python

import time

# رفع وثيقة
document = client.documents.upload(
    file_path="large-document.pdf",
    collection="research"
)

# مراقبة التقدم
print("Processing document...")
while document.status in ["processing", "queued"]:
    document.refresh()  # تحديث الحالة
    print(f"Progress: {document.progress}% - Status: {document.status}")
    time.sleep(2)

if document.status == "completed":
    print(f"✓ Document processed successfully!")
    print(f"  - Pages: {document.pages}")
    print(f"  - Tables: {document.tables_count}")
    print(f"  - Images: {document.images_count}")
    print(f"  - Processing time: {document.processing_time_seconds}s")
else:
    print(f"✗ Processing failed: {document.error_message}")

الحصول على معلومات وثيقة

Python

# بواسطة ID
document = client.documents.get("doc_abc123")

print(f"Filename: {document.filename}")
print(f"Status: {document.status}")
print(f"Pages: {document.pages}")
print(f"Size: {document.size_bytes / 1024 / 1024:.2f} MB")
print(f"Created: {document.created_at}")
print(f"Metadata: {document.metadata}")

قائمة الوثائق

Python

# الحصول على كل الوثائق
documents = client.documents.list()

for doc in documents:
    print(f"- {doc.filename} ({doc.status})")

# مع فلترة
documents = client.documents.list(
    collection="research-2024",
    status="completed",
    page=1,
    page_size=50,
    sort_by="created_at",
    order="desc"
)

print(f"Total: {documents.total}")
print(f"Page: {documents.page}/{documents.total_pages}")

# تصفح كل الصفحات
all_docs = []
for page in range(1, documents.total_pages + 1):
    page_docs = client.documents.list(page=page, page_size=100)
    all_docs.extend(page_docs.items)

print(f"Total documents: {len(all_docs)}")

تحديث بيانات وثيقة

Python

# تحديث metadata
document = client.documents.update(
    document_id="doc_abc123",
    metadata={
        "reviewed": True,
        "reviewer": "Dr. Sarah",
        "review_date": "2024-01-15"
    }
)

حذف وثيقة

Python

# حذف وثيقة واحدة
client.documents.delete("doc_abc123")

# حذف متعدد
doc_ids = ["doc_abc123", "doc_def456", "doc_ghi789"]
for doc_id in doc_ids:
    try:
        client.documents.delete(doc_id)
        print(f"✓ Deleted: {doc_id}")
    except Exception as e:
        print(f"✗ Failed to delete {doc_id}: {e}")

3. البحث
البحث النصي (Full-text Search)

Python

# بحث بسيط
results = client.search.text(
    query="الذكاء الاصطناعي في التعليم",
    collection="research"
)

for result in results:
    print(f"Score: {result.score:.2f}")
    print(f"File: {result.filename}")
    print(f"Page: {result.page}")
    print(f"Snippet: {result.snippet}")
    print("-" * 50)

# بحث متقدم مع فلترة
results = client.search.text(
    query="machine learning",
    collection="research-2024",
    filters={
        "year": {"gte": 2020, "lte": 2024},
        "author": {"in": ["Dr. Ahmed", "Dr. Sarah"]},
        "tags": {"contains": "nlp"}
    },
    limit=20,
    offset=0,
    highlight=True,
    include_metadata=True
)

# الوصول إلى النتائج
print(f"Total results: {results.total}")
for i, result in enumerate(results, 1):
    print(f"\n{i}. {result.filename}")
    print(f"   Score: {result.score:.3f}")
    print(f"   Author: {result.metadata.get('author')}")
    print(f"   Snippet: {result.snippet[:100]}...")

البحث الدلالي (Semantic Search)

Python

# بحث دلالي
results = client.search.semantic(
    query="applications of artificial intelligence in modern education systems",
    collection="research",
    similarity_threshold=0.7,
    limit=10,
    rerank=True
)

for result in results:
    print(f"Similarity: {result.similarity:.3f}")
    print(f"File: {result.filename}")
    print(f"Text: {result.text[:200]}...")
    print()

# بحث متعدد اللغات
results_ar = client.search.semantic(
    query="تطبيقات الذكاء الاصطناعي",
    collection="research",
    language="ara"
)

البحث المختلط (Hybrid Search)

Python

# دمج البحث النصي والدلالي
results = client.search.hybrid(
    query="neural networks deep learning",
    collection="research",
    text_weight=0.3,      # وزن البحث النصي
    semantic_weight=0.7,  # وزن البحث الدلالي
    limit=10
)

for result in results:
    print(f"Combined Score: {result.combined_score:.3f}")
    print(f"  - Text Score: {result.text_score:.3f}")
    print(f"  - Semantic Score: {result.semantic_score:.3f}")
    print(f"File: {result.filename}")
    print()

بحث متقدم مع pagination

Python

# البحث في كل النتائج
def search_all(query, collection, page_size=50):
    """جلب كل نتائج البحث"""
    all_results = []
    offset = 0
    
    while True:
        results = client.search.text(
            query=query,
            collection=collection,
            limit=page_size,
            offset=offset
        )
        
        if not results.items:
            break
        
        all_results.extend(results.items)
        offset += page_size
        
        print(f"Fetched {len(all_results)}/{results.total} results...")
        
        if len(all_results) >= results.total:
            break
    
    return all_results

# استخدام
all_results = search_all("AI", "research")
print(f"Total results found: {len(all_results)}")

4. الدردشة والذكاء الاصطناعي
سؤال وجواب بسيط

Python

# سؤال بسيط
answer = client.chat.ask(
    question="ما هي فوائد الذكاء الاصطناعي في التعليم؟",
    collection="research"
)

print(f"Q: {answer.question}")
print(f"A: {answer.text}")
print(f"\nSources:")
for source in answer.sources:
    print(f"  - {source.filename} (page {source.page})")

سؤال مع خيارات متقدمة

Python

answer = client.chat.ask(
    question="What are the main challenges in implementing AI in education?",
    collection="research-2024",
    model="gpt-4",
    temperature=0.7,
    max_tokens=500,
    system_prompt="You are an expert in educational technology. Provide detailed, academic answers.",
    include_sources=True,
    language="en"
)

print(f"Answer: {answer.text}")
print(f"Model: {answer.model}")
print(f"Tokens used: {answer.tokens_used}")
print(f"Response time: {answer.took_ms}ms")

Streaming Response

Python

# الحصول على الإجابة بشكل تدريجي
stream = client.chat.ask(
    question="شرح مفصل عن الشبكات العصبية العميقة",
    collection="research",
    stream=True
)

print("Answer: ", end="", flush=True)
for chunk in stream:
    print(chunk.content, end="", flush=True)
print("\n")

محادثة متعددة الأدوار

Python

# إنشاء محادثة جديدة
conversation = client.chat.create_conversation(
    collection="research",
    model="gpt-4"
)

# إضافة رسائل
response1 = conversation.send("ما هو الذكاء الاصطناعي؟")
print(f"Bot: {response1.text}\n")

response2 = conversation.send("ما هي تطبيقاته؟")
print(f"Bot: {response2.text}\n")

response3 = conversation.send("أعطني أمثلة عملية")
print(f"Bot: {response3.text}\n")

# عرض تاريخ المحادثة
print("\nConversation History:")
for msg in conversation.messages:
    print(f"{msg.role}: {msg.content}")

# حفظ المحادثة
conversation.save()

# استرجاع محادثة سابقة
old_conversation = client.chat.get_conversation("conv_xyz789")

5. استخراج المعلومات
استخراج النص

Python

# استخراج كل النص
text = client.documents.extract_text("doc_abc123")
print(f"Total words: {text.total_words}")
print(f"Content: {text.full_text[:500]}...")

# استخراج صفحات محددة
text = client.documents.extract_text(
    document_id="doc_abc123",
    pages="1,2,3"  # أو "1-5"
)

for page in text.pages:
    print(f"\n--- Page {page.page_number} ---")
    print(page.text)
    print(f"Word count: {page.word_count}")

# استخراج مع تنسيق
markdown_text = client.documents.extract_text(
    document_id="doc_abc123",
    format="markdown"
)

استخراج الجداول

Python

# استخراج كل الجداول
tables = client.documents.extract_tables("doc_abc123")

print(f"Found {len(tables)} tables")

for i, table in enumerate(tables, 1):
    print(f"\nTable {i} (Page {table.page}):")
    print(f"Size: {table.rows}x{table.columns}")
    
    # عرض كـ DataFrame
    import pandas as pd
    df = pd.DataFrame(table.data[1:], columns=table.data[0])
    print(df)
    
    # حفظ كـ CSV
    df.to_csv(f"table_{i}.csv", index=False)

# استخراج جدول معين
table = client.documents.extract_tables(
    document_id="doc_abc123",
    page=5,
    table_index=0
)

استخراج الصور

Python

# استخراج كل الصور
images = client.documents.extract_images("doc_abc123")

print(f"Found {len(images)} images")

for i, image in enumerate(images, 1):
    print(f"Image {i}:")
    print(f"  Page: {image.page}")
    print(f"  Size: {image.width}x{image.height}")
    print(f"  Format: {image.format}")
    
    # تحميل الصورة
    image_data = image.download()
    with open(f"image_{i}.{image.format}", "wb") as f:
        f.write(image_data)
    
    # أو حفظ مباشرة
    image.save(f"image_{i}.{image.format}")

تلخيص

Python

# تلخيص وثيقة
summary = client.documents.summarize(
    document_id="doc_abc123",
    max_length=500,
    language="ar",
    style="academic"
)

print(f"Original: {summary.original_word_count} words")
print(f"Summary: {summary.word_count} words")
print(f"Compression: {summary.compression_ratio:.1%}")
print(f"\n{summary.text}")

# تلخيص متعدد المستويات
summaries = client.documents.summarize(
    document_id="doc_abc123",
    levels=["brief", "detailed", "comprehensive"]
)

for level, summary in summaries.items():
    print(f"\n{level.upper()} Summary ({summary.word_count} words):")
    print(summary.text)

ترجمة

Python

# ترجمة نص
translation = client.translate(
    text="Artificial intelligence is transforming education",
    source_language="en",
    target_language="ar"
)

print(f"Original: {translation.source_text}")
print(f"Translated: {translation.translated_text}")
print(f"Confidence: {translation.confidence:.2%}")

# ترجمة وثيقة كاملة
translated_doc = client.documents.translate(
    document_id="doc_abc123",
    target_language="ar",
    preserve_formatting=True
)

print(f"Translated document ID: {translated_doc.id}")

6. إدارة المجموعات

Python

# إنشاء مجموعة
collection = client.collections.create(
    name="research-2024",
    description="AI research papers from 2024",
    embedding_model="text-embedding-ada-002",
    metadata={
        "department": "Computer Science",
        "project": "AI in Education"
    }
)

# قائمة المجموعات
collections = client.collections.list()
for coll in collections:
    print(f"- {coll.name}: {coll.document_count} documents")

# الحصول على معلومات مجموعة
collection = client.collections.get("research-2024")
print(f"Name: {collection.name}")
print(f"Documents: {collection.document_count}")
print(f"Size: {collection.total_size_bytes / 1024 / 1024:.2f} MB")

# تحديث مجموعة
collection = client.collections.update(
    name="research-2024",
    description="Updated description"
)

# حذف مجموعة
client.collections.delete("old-collection")

7. معالجة الأخطاء

Python

from bisheng.exceptions import (
    BishengAPIError,
    DocumentNotFoundError,
    AuthenticationError,
    RateLimitError,
    ValidationError
)

# معالجة أخطاء محددة
try:
    document = client.documents.get("invalid_id")
except DocumentNotFoundError:
    print("Document not found")
except AuthenticationError:
    print("Invalid credentials")
except RateLimitError as e:
    print(f"Rate limit exceeded. Retry after {e.retry_after} seconds")
except BishengAPIError as e:
    print(f"API Error: {e.message}")
    print(f"Status Code: {e.status_code}")
    print(f"Request ID: {e.request_id}")

# معالجة شاملة
try:
    result = client.search.text("query", "collection")
except Exception as e:
    print(f"Unexpected error: {e}")

إعادة المحاولة التلقائية

Python

from bisheng import BishengClient
from bisheng.retry import RetryConfig

# تكوين إعادة المحاولة
retry_config = RetryConfig(
    max_retries=3,
    backoff_factor=2,  # تأخير متصاعد: 2, 4, 8 ثواني
    retry_on_status=[500, 502, 503, 504]
)

client = BishengClient(
    api_url="https://your-domain.com/api/v1",
    api_key="your-api-key",
    retry_config=retry_config
)

8. أمثلة متقدمة
معالجة دفعة من الوثائق

Python

import asyncio
from pathlib import Path

async def process_documents_batch(file_paths, collection):
    """معالجة دفعة من الوثائق"""
    tasks = []
    
    for file_path in file_paths:
        task = client.documents.upload_async(
            file_path=file_path,
            collection=collection
        )
        tasks.append(task)
    
    # انتظار كل المهام
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    # معالجة النتائج
    successful = []
    failed = []
    
    for file_path, result in zip(file_paths, results):
        if isinstance(result, Exception):
            failed.append((file_path, str(result)))
        else:
            successful.append(result)
    
    return successful, failed

# استخدام
files = list(Path("./documents").glob("*.pdf"))
successful, failed = asyncio.run(
    process_documents_batch(files, "research-2024")
)

print(f"Successful: {len(successful)}")
print(f"Failed: {len(failed)}")

بناء نظام RAG مخصص

Python

class CustomRAG:
    """نظام RAG مخصص"""
    
    def __init__(self, client, collection):
        self.client = client
        self.collection = collection
    
    def ask(self, question, top_k=5, rerank=True):
        """سؤال مع استرجاع مخصص"""
        # 1. البحث عن المستندات ذات الصلة
        search_results = self.client.search.hybrid(
            query=question,
            collection=self.collection,
            limit=top_k * 2  # جلب أكثر للإعادة ترتيب
        )
        
        # 2. إعادة ترتيب النتائج
        if rerank:
            reranked = self._rerank(question, search_results[:top_k])
        else:
            reranked = search_results[:top_k]
        
        # 3. بناء السياق
        context = self._build_context(reranked)
        
        # 4. توليد الإجابة
        answer = self.client.chat.ask(
            question=question,
            collection=self.collection,
            context=context,
            include_sources=True
        )
        
        return answer
    
    def _rerank(self, query, results):
        """إعادة ترتيب النتائج"""
        # يمكن استخدام نموذج reranking مخصص
        return sorted(results, key=lambda x: x.combined_score, reverse=True)
    
    def _build_context(self, results):
        """بناء السياق من النتائج"""
        context_parts = []
        for i, result in enumerate(results, 1):
            context_parts.append(
                f"[Document {i}: {result.filename}, Page {result.page}]\n"
                f"{result.text}\n"
            )
        return "\n".join(context_parts)

# استخدام
rag = CustomRAG(client, "research-2024")
answer = rag.ask("What are the benefits of AI in education?")
print(answer.text)

مراقبة الأداء

Python

import time
from contextlib import contextmanager

@contextmanager
def timer(name):
    """قياس وقت التنفيذ"""
    start = time.time()
    yield
    end = time.time()
    print(f"{name}: {end - start:.2f}s")

# استخدام
with timer("Document upload"):
    doc = client.documents.upload("large-file.pdf")

with timer("Search"):
    results = client.search.text("query", "collection")

with timer("Question answering"):
    answer = client.chat.ask("question", "collection")

9. التكامل مع Frameworks
LangChain Integration

Python

from langchain.document_loaders import BishengLoader
from langchain.vectorstores import BishengVectorStore
from langchain.chains import RetrievalQA
from langchain.llms import OpenAI

# تحميل الوثائق
loader = BishengLoader(
    client=client,
    collection="research-2024"
)
documents = loader.load()

# إنشاء vector store
vectorstore = BishengVectorStore(
    client=client,
    collection="research-2024"
)

# إنشاء QA chain
qa_chain = RetrievalQA.from_chain_type(
    llm=OpenAI(),
    retriever=vectorstore.as_retriever(),
    return_source_documents=True
)

# طرح سؤال
result = qa_chain({"query": "What is AI?"})
print(result["result"])

LlamaIndex Integration

Python

from llama_index import BishengReader, GPTVectorStoreIndex

# قراءة الوثائق
reader = BishengReader(client=client)
documents = reader.load_data(collection="research-2024")

# إنشاء index
index = GPTVectorStoreIndex.from_documents(documents)

# الاستعلام
query_engine = index.as_query_engine()
response = query_engine.query("What are AI applications?")
print(response)

10. أفضل الممارسات
استخدام Connection Pooling

Python

from bisheng import BishengClient
from bisheng.session import PooledSession

# إنشاء session مع connection pooling
session = PooledSession(
    pool_connections=10,
    pool_maxsize=20
)

client = BishengClient(
    api_url="https://your-domain.com/api/v1",
    api_key="your-api-key",
    session=session
)

Caching

Python

from functools import lru_cache

@lru_cache(maxsize=1000)
def search_cached(query, collection):
    """بحث مع caching"""
    results = client.search.text(query, collection)
    return results

# استخدام
results1 = search_cached("AI", "research")  # من API
results2 = search_cached("AI", "research")  # من cache

Batch Processing

Python

def process_in_batches(items, batch_size=10):
    """معالجة على دفعات"""
    for i in range(0, len(items), batch_size):
        batch = items[i:i + batch_size]
        yield batch

# استخدام
documents = list(Path("./docs").glob("*.pdf"))
for batch in process_in_batches(documents, batch_size=5):
    for doc in batch:
        client.documents.upload(doc, collection="research")
    time.sleep(1)  # تجنب rate limiting

📖 مراجع إضافية

    API Reference
    GitHub Repository
    Examples
    Changelog

