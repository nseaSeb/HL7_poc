# HL7_poc

## HL7 to JSON Parser demo (Elixir)

A lightweight, reliable HL7 message parser built in Elixir.

## 🎯 Problem

HL7 (Health Level 7) is a healthcare data standard used worldwide. But:
- Text-based format = hard to parse
- Complex structure = error-prone
- Integration with modern systems = painful

Modern APIs need JSON. This parser bridges the gap.
Use Postgres JSONB

## ✅ Solution

Parse HL7 messages into clean JSON with:
- ✅ Type safety (Elixir pattern matching)
- ✅ Error handling (graceful failures)
- ✅ Performance (Elixir concurrency)
- ✅ Performance search (Postgres JSONB)

## Sample datas used for demo

'''plaintext
MSH|^~\&|LAB|HOSPITAL|EHR|CLINIC|202311041200||ORU^R01|12345|P|2.3.1
PID|1||123456^^^HOSPITAL||DUPONT^JEAN||19800101|M|||123 RUE DU TEST^^BORDEAUX^^33000||0600000000
OBR|1|A123|B456|GLUCOSE^Blood glucose|||202311041200|||||DR HOUSE
OBX|1|NM|GLUCOSE^Blood glucose||5.4|mmol/L|3.9-6.1|N|||F
```

### 3. Run this demo

```bash
docker compose up --build
```
