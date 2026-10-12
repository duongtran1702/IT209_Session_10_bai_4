#!/bin/bash
# ==============================================================================
# Script: commands.sh
# Bài tập: Bài 4 - Thiết lập Custom Network & Named Volume bằng Docker CLI
# Môn học: IT209 - Quản lý Phiên bản và Hợp tác Mã nguồn / Linux Administration
# Học viên: Trần Trí Dương (duongtran1702) - Lớp: IT209
# ==============================================================================

set -e

# Định nghĩa mã màu hiển thị
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}>>> BẮT ĐẦU THỰC THI SCRIPT DOCKER CLI (EX4 - SESSION 10) <<<${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 0: DỌN DẸP TÀI NGUYÊN CŨ (NẾU CÓ) ĐỂ ĐẢM BẢO TÍNH ĐỘC LẬP
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[BƯỚC 0] Dọn dẹp container, volume và network cũ...${NC}"
docker rm -f db-server app-container 2>/dev/null || true
docker volume rm db-data 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
echo -e "${GREEN}✓ Hoàn tất dọn dẹp môi trường sạch.${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 1: TẠO CUSTOM BRIDGE NETWORK (app-net)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[BƯỚC 1] Tạo Custom Bridge Network: app-net...${NC}"
docker network create --driver bridge app-net
echo -e "${GREEN}✓ Đã tạo thành công network 'app-net'.${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 2: TẠO NAMED VOLUME (db-data)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[BƯỚC 2] Tạo Named Volume: db-data...${NC}"
docker volume create db-data
echo -e "${GREEN}✓ Đã tạo thành công volume 'db-data'.${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 3: BUILD BACKEND IMAGE TỪ DOCKERFILE
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[BƯỚC 3] Build Backend Web API Image (backend-api:v1)...${NC}"
docker build -t backend-api:v1 .
echo -e "${GREEN}✓ Build image 'backend-api:v1' hoàn tất.${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 4: KHỞI CHẠY DATABASE CONTAINER (postgres:15-alpine)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[BƯỚC 4] Khởi chạy Database Container (db-server) gắn volume db-data và network app-net...${NC}"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secretpassword123 \
  postgres:15-alpine

echo -e "${CYAN}Đang chờ PostgreSQL db-server sẵn sàng nhận kết nối...${NC}"
until docker exec db-server pg_isready -U appuser -d appdb > /dev/null 2>&1; do
  sleep 1
done
echo -e "${GREEN}✓ PostgreSQL container 'db-server' đã sẵn sàng!${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 5: KHỞI CHẠY BACKEND CONTAINER (app-container)
# ------------------------------------------------------------------------------
echo -e "\n${YELLOW}[BƯỚC 5] Khởi chạy Backend Container (app-container) tham gia app-net...${NC}"
docker run -d \
  --name app-container \
  --network app-net \
  -p 8080:8080 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASSWORD=secretpassword123 \
  backend-api:v1

sleep 3
echo -e "${GREEN}✓ Backend container 'app-container' đã khởi chạy thành công.${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 6: KIỂM TRA NETWORK, VOLUME VÀ DNS RESOLUTION (PING)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${YELLOW}[BƯỚC 6] KIỂM TRA HỆ THỐNG MẠNG & VOLUME THEO YÊU CẦU ĐỀ BÀI${NC}"
echo -e "${BLUE}==============================================================================${NC}"

echo -e "\n${CYAN}1. Kiểm tra tồn tại của Network 'app-net':${NC}"
docker network ls | grep app-net

echo -e "\n${CYAN}2. Kiểm tra tồn tại của Volume 'db-data':${NC}"
docker volume ls | grep db-data

echo -e "\n${CYAN}3. Inspect thông tin Network 'app-net' (danh sách container tham gia):${NC}"
docker network inspect app-net

echo -e "\n${CYAN}4. Kiểm tra DNS Resolution nội bộ (app-container ping -c 2 db-server):${NC}"
docker exec app-container ping -c 2 db-server
echo -e "${GREEN}✓ Lệnh ping db-server từ Backend container đã giải mã IP nội bộ thành công!${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 7: TEST DATA PERSISTENCE (LƯU TRỮ DỮ LIỆU BỀN VỮNG)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${YELLOW}[BƯỚC 7] THỰC HIỆN KIỂM THỬ DATA PERSISTENCE TRÊN NAMED VOLUME${NC}"
echo -e "${BLUE}==============================================================================${NC}"

echo -e "\n${CYAN}7.1. Chèn dữ liệu mẫu vào bảng 'inventory' trong DB container hiện tại...${NC}"
docker exec -i db-server psql -U appuser -d appdb -c "
CREATE TABLE IF NOT EXISTS inventory (
  id SERIAL PRIMARY KEY,
  item_name VARCHAR(100) NOT NULL,
  quantity INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO inventory (item_name, quantity) VALUES
  ('Docker Named Volume Persistent Check', 10),
  ('Custom Bridge Network DNS Resolution', 20),
  ('PostgreSQL Database Snapshot Record', 99);
"

echo -e "\n${CYAN}7.2. Dữ liệu trong database TRƯỚC KHI XÓA container:${NC}"
docker exec -i db-server psql -U appuser -d appdb -c "SELECT id, item_name, quantity, created_at FROM inventory;"

echo -e "\n${RED}7.3. TIẾN HÀNH XÓA CỨNG CONTAINER DB (docker rm -f db-server)...${NC}"
docker rm -f db-server
echo -e "${GREEN}✓ Đã xóa cứng container db-server thành công.${NC}"

echo -e "\n${CYAN}7.4. Khởi chạy lại Container DB MỚI gắn cùng Volume 'db-data' và Network 'app-net'...${NC}"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secretpassword123 \
  postgres:15-alpine

echo -e "${CYAN}Đang chờ container DB mới sẵn sàng...${NC}"
until docker exec db-server pg_isready -U appuser -d appdb > /dev/null 2>&1; do
  sleep 1
done

echo -e "\n${CYAN}7.5. XÁC MINH DỮ LIỆU SAU KHI TÁI TẠO CONTAINER MỚI (Data Persistence):${NC}"
docker exec -i db-server psql -U appuser -d appdb -c "SELECT id, item_name, quantity, created_at FROM inventory;"
echo -e "${GREEN}✓ XÁC NHẬN: Toàn bộ dữ liệu vẫn còn nguyên vẹn trên Named Volume db-data!${NC}"

# ------------------------------------------------------------------------------
# BƯỚC 8: KIỂM TRA PHẢN HỒI BACKEND API
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${YELLOW}[BƯỚC 8] KIỂM TRA KẾT NỐI QUA BACKEND REST API (HTTP)${NC}"
echo -e "${BLUE}==============================================================================${NC}"

echo -e "\n${CYAN}8.1. Kiểm tra Healthcheck Endpoint (http://localhost:8080/health):${NC}"
curl -s http://localhost:8080/health || true
echo ""

echo -e "\n${CYAN}8.2. Kiểm tra Data Endpoint (http://localhost:8080/api/items):${NC}"
curl -s http://localhost:8080/api/items || true
echo ""

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}>>> HOÀN THÀNH TOÀN BỘ KỊCH BẢN THỰC THI BÀI 4 THÀNH CÔNG RỰC RỠ! <<<${NC}"
echo -e "${GREEN}==============================================================================${NC}"
