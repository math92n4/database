# Database Mandatory
## Nordic Electronincs

**Setup Instructions**

Clone the repository

```bash
git clone https://github.com/math92n4/database
cd database
```

Create a .env file in root directory <br>
EXAMPLE
```bash
POSTGRES_DB=webshop
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
```

Docker compose
```bash
docker-compose up -d --build
```

This will run the script in /scripts/init.sql which contains tables, indexes, procedures, views, functions, triggers, events

### ER Diagram
<img width="1551" height="1156" alt="image" src="https://github.com/user-attachments/assets/7125dd6f-a256-418e-af6c-1a07917394f6" />
