# WebUntis API Documentation

## Server Configuration

| Parameter | Value |
|-----------|-------|
| Server | `gymbruck.webuntis.com` |
| School | `gymbruck` |
| API Endpoint | `https://gymbruck.webuntis.com/WebUntis/jsonrpc.do?school=gymbruck` |
| Username | `Schueler` |
| Password | `IbSvGB2023!` |

## Authentication

### Login Request

```bash
curl -X POST "https://gymbruck.webuntis.com/WebUntis/jsonrpc.do?school=gymbruck" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "1",
    "method": "authenticate",
    "params": {
      "user": "Schueler",
      "password": "IbSvGB2023!",
      "client": "MyApp"
    },
    "jsonrpc": "2.0"
  }'
```

### Login Response

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "sessionId": "2FEEAEDDAEDAB9DD80391745F354873B",
    "personType": 1,
    "personId": 0,
    "klasseId": 0
  }
}
```

Use the `sessionId` as cookie for subsequent requests: `Cookie: JSESSIONID=<sessionId>`

## API Methods

### Available Methods (Schueler account)

| Method | Description | Access |
|--------|-------------|--------|
| `authenticate` | Login | Yes |
| `logout` | Logout | Yes |
| `getKlassen` | Get all classes | Yes |
| `getTimetable` | Get timetable | Yes |
| `getSubjects` | Get all subjects | Yes |
| `getRooms` | Get all rooms | Yes |
| `getHolidays` | Get holidays | Yes |
| `getTimegridUnits` | Get time grid | Yes |
| `getTeachers` | Get all teachers | **No** (error -8509) |
| `getStudents` | Get all students | **No** |

### Get Classes

```bash
curl -X POST "https://gymbruck.webuntis.com/WebUntis/jsonrpc.do?school=gymbruck" \
  -H "Content-Type: application/json" \
  -H "Cookie: JSESSIONID=<session>" \
  -d '{"id": "2", "method": "getKlassen", "params": {}, "jsonrpc": "2.0"}'
```

Response contains class objects with `id`, `name`, `longName`, `active`, `teacher1`, `teacher2`.

**Class IDs:**
- 5A-5D: 1103-1112
- 6A-6D: 1115-1124
- 7A-7D: 1127-1136
- 8A-8D: 1139-1148
- 9A-9C: 1151-1157
- 10A-10C: 1160-1166
- 11A-11C: 1169-1175
- **12: 1178**
- 13: 1181

### Get Timetable (Basic)

```bash
curl -X POST "https://gymbruck.webuntis.com/WebUntis/jsonrpc.do?school=gymbruck" \
  -H "Content-Type: application/json" \
  -H "Cookie: JSESSIONID=<session>" \
  -d '{
    "id": "3",
    "method": "getTimetable",
    "params": {
      "id": 1178,
      "type": 1,
      "startDate": 20260119,
      "endDate": 20260125
    },
    "jsonrpc": "2.0"
  }'
```

### Get Timetable (Extended with Names)

This is the key to getting teacher names without `getTeachers()` permission!

```bash
curl -X POST "https://gymbruck.webuntis.com/WebUntis/jsonrpc.do?school=gymbruck" \
  -H "Content-Type: application/json" \
  -H "Cookie: JSESSIONID=<session>" \
  -d '{
    "id": "4",
    "method": "getTimetable",
    "params": {
      "options": {
        "element": {"id": 1178, "type": 1},
        "startDate": 20260119,
        "endDate": 20260125,
        "showInfo": true,
        "showSubstText": true,
        "showLsText": true,
        "showLsNumber": true,
        "showStudentgroup": true,
        "klasseFields": ["id", "name", "longname"],
        "roomFields": ["id", "name", "longname"],
        "subjectFields": ["id", "name", "longname"],
        "teacherFields": ["id", "name", "longname"]
      }
    },
    "jsonrpc": "2.0"
  }'
```

#### Extended Response Example

```json
{
  "id": 1475279,
  "date": 20260119,
  "startTime": 750,
  "endTime": 835,
  "kl": [{"id": 1178, "name": "12", "longname": "12"}],
  "te": [{"id": 67, "name": "SP", "longname": "Spreitzer"}],
  "su": [{"id": 1, "name": "B", "longname": "Biologie"}],
  "ro": [{"id": 29, "name": "E21", "longname": "E21"}],
  "lsnumber": 33300,
  "activityType": "Unterricht"
}
```

#### Available Field Options

| Option | Fields | Description |
|--------|--------|-------------|
| `teacherFields` | `["id", "name", "longname"]` | Teacher abbreviation & full name |
| `subjectFields` | `["id", "name", "longname"]` | Subject abbreviation & full name |
| `roomFields` | `["id", "name", "longname"]` | Room abbreviation & full name |
| `klasseFields` | `["id", "name", "longname"]` | Class abbreviation & full name |

#### Element Types

| Type | Description |
|------|-------------|
| 1 | Klasse (class) |
| 2 | Teacher |
| 3 | Subject |
| 4 | Room |
| 5 | Student |

### Timetable Entry Fields

| Field | Description |
|-------|-------------|
| `id` | Lesson ID |
| `date` | Date (YYYYMMDD format) |
| `startTime` | Start time (e.g., 750 = 07:50) |
| `endTime` | End time (e.g., 835 = 08:35) |
| `kl` | Classes array |
| `te` | Teachers array |
| `su` | Subjects array |
| `ro` | Rooms array |
| `code` | Status (`"cancelled"` if lesson is cancelled) |
| `activityType` | Type of activity (e.g., "Unterricht") |
| `lsnumber` | Lesson number |

## Teacher Abbreviations (Gymnasium Bruckmühl)

Extracted from timetable data:

| Abbrev | Full Name | Subjects |
|--------|-----------|----------|
| AG | ? | Mathe (M) |
| BC | ? | Geo, TuF |
| BI | ? | Kunst (Ku) |
| BM | ? | Musik (Mu) |
| BS | ? | Geschichte (G) |
| BU | ? | Kath. Religion (K) |
| DR | ? | Französisch (F) |
| EB | Eberl | Biologie (B) |
| FR | ? | Englisch (E) |
| GA | ? | Sport (Smw) |
| HK | ? | W-Sem |
| HM | ? | Ev. Religion (Ev) |
| HN | ? | Geo, PuG |
| HP | ? | Deutsch (D) |
| KO | ? | Physik (Ph), W-Sem |
| KT | ? | Geschichte (G) |
| LD | ? | Ethik, Latein (L) |
| LO | ? | Physik (Ph), Mathe (M) |
| ME | ? | Geschichte (G), W-Sem |
| MF | ? | PuG |
| MM | ? | Deutsch (D), E-Konv |
| MÜ | ? | WR, Mathe, vkM |
| NG | ? | Geographie (Geo) |
| PI | ? | Englisch (E) |
| SK | Stahl | Biologie (B) |
| SO | ? | Englisch (E) |
| SP | Spreitzer | Biologie (B) |
| SU | ? | Kath. Religion (K), W-Sem |
| TO | ? | Kunst (Ku) |
| WA | ? | Sport (Smw) |
| WJ | ? | Deutsch (D), PuG |
| WL | ? | Musik (Ins, VOC, Mu) |
| WM | ? | Sport (Smw), S-T |
| ZU | ? | Chemie (C) |

## Subject Abbreviations

| Abbrev | Full Name |
|--------|-----------|
| B | Biologie |
| C | Chemie |
| D | Deutsch |
| E | Englisch |
| Eth | Ethik |
| Ev | Evangelische Religion |
| F | Französisch |
| G | Geschichte |
| Geo | Geographie |
| Inf | Informatik |
| K | Katholische Religion |
| Ku | Kunst |
| L | Latein |
| M | Mathe |
| Mu | Musik |
| Ph | Physik |
| PuG | Politik und Gesellschaft |
| Smw | Sport (männlich/weiblich) |
| S-T | ? |
| WR | Wirtschaft und Recht |
| W-Sem | Wissenschaftspropädeutisches Seminar |
| EKo | Englisch Konversation |
| Ins | Instrumentalunterricht |
| VOC | Vokalensemble/Chor |
| TuF | ? |
| vkM | vertiefender Kurs Mathe |

## Room Abbreviations

| Abbrev | Description |
|--------|-------------|
| E08-E14 | Erdgeschoss Räume |
| E21-E27 | Erdgeschoss Räume (Naturwissenschaften) |
| 108-114 | 1. Stock |
| 208-214 | 2. Stock |
| 223-229 | 2. Stock |
| Ph1, Ph2, PhÜb | Physik-Säle |
| Inf1, Inf2 | Informatik-Räume |
| Musik1, Musik2 | Musikräume |
| Kunst, KunstW | Kunsträume |
| Halle | Sporthalle |

## Python Library

Install: `pip install webuntis`

```python
import webuntis
import datetime

with webuntis.Session(
    server='gymbruck.webuntis.com',
    school='gymbruck',
    username='Schueler',
    password='IbSvGB2023!',
    useragent='MyApp'
).login() as s:
    
    # Get all classes
    for klasse in s.klassen():
        print(klasse.name)
    
    # Get timetable for class 12 (id=1178)
    today = datetime.date.today()
    monday = today - datetime.timedelta(days=today.weekday())
    friday = monday + datetime.timedelta(days=4)
    
    klasse = s.klassen().filter(name='12')[0]
    tt = s.timetable(klasse=klasse, start=monday, end=friday)
    
    for period in tt:
        print(f"{period.start} - {period.end}: {period.subjects}")
```

## Error Codes

| Code | Message |
|------|---------|
| -8509 | No right for method (e.g., getTeachers) |
| -8520 | Not authenticated |
| -8504 | Invalid schoolname |
