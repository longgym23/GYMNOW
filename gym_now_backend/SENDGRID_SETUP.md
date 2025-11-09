# Hướng dẫn cấu hình SendGrid để gửi email

## Tại sao dùng SendGrid?

Render free tier thường **block outbound SMTP connections**, nên không thể dùng Gmail SMTP. SendGrid sử dụng REST API, không cần SMTP, nên hoạt động tốt trên Render.

## Bước 1: Tạo tài khoản SendGrid

1. Truy cập: https://signup.sendgrid.com/
2. Đăng ký tài khoản miễn phí (100 emails/ngày)
3. Xác thực email và hoàn tất đăng ký

## Bước 2: Tạo API Key

1. Đăng nhập vào SendGrid Dashboard
2. Vào **Settings** → **API Keys**
3. Click **Create API Key**
4. Đặt tên: "GymNow Backend"
5. Chọn quyền: **Full Access** (hoặc chỉ **Mail Send**)
6. Click **Create & View**
7. **Copy API Key ngay** (chỉ hiển thị 1 lần!)

## Bước 3: Verify Sender Email

1. Vào **Settings** → **Sender Authentication**
2. Click **Verify a Single Sender**
3. Điền form "Create a Sender" với các thông tin sau:

   **Các trường bắt buộc (có dấu đỏ):**
   
   - **From Name**: `GymNow` (hoặc tên bạn muốn hiển thị)
   - **From Email Address**: Email bạn muốn dùng để gửi (ví dụ: `your-email@gmail.com` hoặc `noreply@gymnow.com`)
     - ⚠️ **Lưu ý**: Email này phải là email bạn có quyền truy cập để xác thực
   - **Reply To**: Cùng email với "From Email Address" (hoặc email khác nếu muốn)
   - **Company Address**: Địa chỉ công ty/cá nhân của bạn (ví dụ: `123 Main Street`)
   - **City**: Thành phố (ví dụ: `Ho Chi Minh City`)
   - **State**: Chọn state (nếu ở Mỹ) hoặc để trống nếu không áp dụng
   - **Zip Code**: Mã bưu điện (ví dụ: `70000`)
   - **Country**: Chọn quốc gia của bạn (ví dụ: `Vietnam`)
   
   **Trường tùy chọn:**
   - **Company Address Line 2**: Có thể để trống

4. Click **Create** hoặc **Save** để tạo sender
5. SendGrid sẽ gửi email xác thực đến địa chỉ "From Email Address"
6. **Kiểm tra hộp thư email** và click vào link xác thực
7. Sau khi xác thực thành công, **lưu lại email "From Email Address"** để dùng làm `EMAIL_FROM` trong Render

## Bước 4: Cấu hình trên Render

1. Vào Render Dashboard → Chọn service backend
2. Vào tab **Environment**
3. Thêm các biến môi trường:
   ```
   SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   EMAIL_FROM=noreply@gymnow.com
   ```
   (Thay `SG.xxx...` bằng API Key thực tế của bạn)

4. **Restart service**

## Bước 5: Test

Sau khi restart, test lại chức năng quên mật khẩu. Email sẽ được gửi qua SendGrid API.

## Lưu ý:

- SendGrid free tier: **100 emails/ngày**
- Email `EMAIL_FROM` phải được verify trong SendGrid
- API Key phải có quyền **Mail Send**
- Không cần cài thêm package, đã dùng `https` module có sẵn của Node.js

