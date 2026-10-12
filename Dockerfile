# Base image Node.js Alpine nhe va bao mat
FROM node:18-alpine

# Cai dat ping (iputils) va curl de ho tro test DNS resolution noi bo va ping service giua cac container
RUN apk add --no-cache iputils curl

# Thiet lap thu muc lam viec
WORKDIR /app

# Sao chep danh sach goi va cai dat dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Sao chep toan bo ma nguon ung dung
COPY . .

# Mo cong 8080
EXPOSE 8080

# Lenh khoi chay ung dung
CMD ["node", "server.js"]
