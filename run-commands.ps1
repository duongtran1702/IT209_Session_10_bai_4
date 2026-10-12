# ==============================================================================
# Script: run-commands.ps1 (Phien ban PowerShell danh cho moi truong Windows)
# Bai tap: Bai 4 - Thiet lap Custom Network & Named Volume bang Docker CLI
# ==============================================================================

Write-Host "==============================================================================" -ForegroundColor Blue
Write-Host ">>> BAT DAU THUC THI DOCKER CLI (EX4 - SESSION 10) TREN POWERSHELL <<<" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Blue

# 0. Don dep
Write-Host "`n[BUOC 0] Don dep container, volume va network cu..." -ForegroundColor Yellow
docker rm -f db-server app-container 2>$null | Out-Null
docker volume rm db-data 2>$null | Out-Null
docker network rm app-net 2>$null | Out-Null

# 1. Tao network
Write-Host "`n[BUOC 1] Tao Custom Bridge Network: app-net..." -ForegroundColor Yellow
docker network create --driver bridge app-net

# 2. Tao volume
Write-Host "`n[BUOC 2] Tao Named Volume: db-data..." -ForegroundColor Yellow
docker volume create db-data

# 3. Build image
Write-Host "`n[BUOC 3] Build Backend Image (backend-api:v1)..." -ForegroundColor Yellow
docker build -t backend-api:v1 .

# 4. Chay db-server
Write-Host "`n[BUOC 4] Khoi chay Database Container (db-server)..." -ForegroundColor Yellow
docker run -d `
  --name db-server `
  --network app-net `
  -v db-data:/var/lib/postgresql/data `
  -e POSTGRES_DB=appdb `
  -e POSTGRES_USER=appuser `
  -e POSTGRES_PASSWORD=secretpassword123 `
  postgres:15-alpine

Write-Host "Cho PostgreSQL khoi dong..." -ForegroundColor Cyan
do {
    Start-Sleep -Seconds 1
    $ready = docker exec db-server pg_isready -U appuser -d appdb 2>$null
} while ($LASTEXITCODE -ne 0)
Write-Host "PostgreSQL da san sang!" -ForegroundColor Green

# 5. Chay app-container
Write-Host "`n[BUOC 5] Khoi chay Backend Container (app-container)..." -ForegroundColor Yellow
docker run -d `
  --name app-container `
  --network app-net `
  -p 8080:8080 `
  -e DB_HOST=db-server `
  -e DB_PORT=5432 `
  -e DB_NAME=appdb `
  -e DB_USER=appuser `
  -e DB_PASSWORD=secretpassword123 `
  backend-api:v1

Start-Sleep -Seconds 3

# 6. Kiem tra
Write-Host "`n==============================================================================" -ForegroundColor Blue
Write-Host "[BUOC 6] KIEM TRA HE THONG MANG & VOLUME" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Blue

Write-Host "`n1. Kiem tra network 'app-net':" -ForegroundColor Cyan
docker network ls | Select-String "app-net"

Write-Host "`n2. Kiem tra volume 'db-data':" -ForegroundColor Cyan
docker volume ls | Select-String "db-data"

Write-Host "`n3. Inspect network 'app-net':" -ForegroundColor Cyan
docker network inspect app-net

Write-Host "`n4. Kiem tra DNS Resolution noi bo (ping db-server tu app-container):" -ForegroundColor Cyan
docker exec app-container ping -c 2 db-server

# 7. Persistence Test
Write-Host "`n==============================================================================" -ForegroundColor Blue
Write-Host "[BUOC 7] KIEM THU DATA PERSISTENCE" -ForegroundColor Yellow
Write-Host "==============================================================================" -ForegroundColor Blue

Write-Host "`n7.1. Chen du lieu vao PostgreSQL:" -ForegroundColor Cyan
docker exec -i db-server psql -U appuser -d appdb -c "
CREATE TABLE IF NOT EXISTS inventory (id SERIAL PRIMARY KEY, item_name VARCHAR(100), quantity INT);
INSERT INTO inventory (item_name, quantity) VALUES ('Docker Named Volume Test', 10), ('Network DNS Resolved', 20);
"

Write-Host "`n7.2. Du lieu truoc khi xoa DB container:" -ForegroundColor Cyan
docker exec -i db-server psql -U appuser -d appdb -c "SELECT * FROM inventory;"

Write-Host "`n7.3. XOA CUNG DB CONTAINER: docker rm -f db-server" -ForegroundColor Red
docker rm -f db-server

Write-Host "`n7.4. Khoi chay container DB moi voi volume db-data cu:" -ForegroundColor Cyan
docker run -d `
  --name db-server `
  --network app-net `
  -v db-data:/var/lib/postgresql/data `
  -e POSTGRES_DB=appdb `
  -e POSTGRES_USER=appuser `
  -e POSTGRES_PASSWORD=secretpassword123 `
  postgres:15-alpine

do {
    Start-Sleep -Seconds 1
    $ready = docker exec db-server pg_isready -U appuser -d appdb 2>$null
} while ($LASTEXITCODE -ne 0)

Write-Host "`n7.5. XAC MINH DU LIEU SAU KHI TAI TAO CONTAINER:" -ForegroundColor Green
docker exec -i db-server psql -U appuser -d appdb -c "SELECT * FROM inventory;"

Write-Host "`nHoan thanh kiem tra!" -ForegroundColor Green
