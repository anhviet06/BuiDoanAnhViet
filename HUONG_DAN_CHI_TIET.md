# TimeGuard - Ứng dụng chấm công nhân viên

Gồm hai phần:

| Thư mục | Nội dung |
|---|---|
| `backend\Buidoananhviet.Api` | ASP.NET Core Web API (.NET 10) + EF Core + SQL Server LocalDB, xác thực JWT, đăng nhập 2 bước bằng OTP, Swagger, 5 ca cố định + QR cố định |
| `app` | Ứng dụng Flutter (Material 3, tiếng Việt, tự đổi sáng/tối theo hệ thống) |

Vai trò: **admin** (quản trị) và **employee** (nhân viên).
Chức năng nâng cao: **xác thực khuôn mặt thật** (liveness: `camera` + `google_mlkit_face_detection`, chạy trên máy), **GPS** (`geolocator` + server tính khoảng cách Haversine), **quét QR** (`mobile_scanner` + `qr_flutter`, có nhập mã tay dự phòng), cảnh báo gian lận (GPS giả, một máy chấm công cho nhiều người), tự tính lương và phạt đi trễ, báo cáo tháng có biểu đồ (`fl_chart`).

> Ghi chép kỹ thuật chi tiết (endpoint, quy tắc chấm công, quyết định thiết kế, kết quả kiểm thử từng giai đoạn): xem `backend\CLAUDE.md`.

---

## 1. Yêu cầu

- Windows, **.NET SDK 10** (đã dùng 10.0.201), công cụ `dotnet-ef` (`dotnet tool install -g dotnet-ef`).
- **SQL Server LocalDB** (`(localdb)\MSSQLLocalDB`, đi kèm Visual Studio / SQL Server Express).
- **Flutter 3.47+** (Dart 3.13+), Android SDK, một máy ảo Android (đã thử: Pixel 6, Android 17 / API 37, x86_64).
- VS Code là đủ; không cần Visual Studio. Không dùng file `.sln`.

## 2. Chạy backend

```powershell
cd D:\Buidoananhviet\backend\Buidoananhviet.Api
dotnet run
```

- Lắng nghe `http://0.0.0.0:5000` (máy ảo Android gọi qua `http://10.0.2.2:5000`).
- Lần đầu tự tạo database `Buidoananhviet`, áp dụng migration, rồi đồng bộ **cấu hình công ty + 5 ca cố định** (mã QR cố định, xem mục 4). **Không tự tạo tài khoản nào.**
- Swagger: <http://localhost:5000/swagger> (nút **Authorize** để dán JWT).
- Kiểm tra sống: <http://localhost:5000/api/health>.

### Cấu hình và bí mật

Không có bí mật nào nằm trong mã nguồn. File `appsettings.json` để trống khóa; giá trị cho môi trường phát triển nằm ở `appsettings.Development.json` (đã `.gitignore`). Mẫu đầy đủ: `appsettings.Example.json`.

| Khóa | Ý nghĩa |
|---|---|
| `ConnectionStrings:DefaultConnection` | Chuỗi kết nối SQL Server (đặt provider ở một chỗ duy nhất trong `Program.cs`) |
| `Jwt:Key` | Khóa ký JWT, >= 32 ký tự (bắt buộc) |
| `Otp:DevMode` | `true`: OTP được in ra console backend **và** trả kèm trong response đăng nhập (app hiện banner "Chế độ demo" + nút Tự điền). `false`: gửi OTP qua email SMTP |
| `Smtp:*` | Máy chủ SMTP (MailKit) khi `Otp:DevMode=false`: `Host`, `Port`, `Username` (hoặc `User`), `Password`, `FromEmail` (hoặc `From`), `FromName`. Gmail: dùng *mật khẩu ứng dụng* (dấu cách được bỏ tự động), port 587 STARTTLS |
| `Seed:EmployeePassword` | Mật khẩu của 5 nhân viên mẫu (chỉ dùng khi chạy `--reset-demo`) |
| `Seed:EmailBase` | Email gốc để sinh email nhận OTP thật của nhân viên mẫu: `<trước @>+<username>@<miền>` (vd. `buianhviet06@gmail.com` -> `buianhviet06+lananh@gmail.com`, tất cả về chung một hộp thư Gmail) |
| `Seed:AdminPassword` | Không còn dùng để tạo admin (backend không tự tạo user). Giữ lại để test tích hợp biết mật khẩu admin của DB tạm |
| `Time:UtcOffsetHours` | Múi giờ của công ty (mặc định 7 = Việt Nam). Giờ ca là giờ địa phương, DB lưu UTC |
| `Attendance:EarlyCheckInMinutes` | Cho phép chấm công sớm bao nhiêu phút trước giờ ca (mặc định 30) |

Ghi đè bằng biến môi trường, ví dụ `Jwt__Key`, `Smtp__Password`.

Lệnh migration (chỉ dùng dotnet CLI):

```powershell
cd D:\Buidoananhviet\backend\Buidoananhviet.Api
dotnet ef migrations add TenMigration
dotnet ef database update
```

## 3. Chạy app Flutter

```powershell
cd D:\Buidoananhviet\app
flutter pub get
flutter run -d <id-may-ao>      # xem danh sách: flutter devices
```

URL API nằm ở **một chỗ duy nhất**: `app\lib\core\config.dart` (`AppConfig.baseUrl = http://10.0.2.2:5000`, đúng cho máy ảo Android). Dùng thiết bị thật thì đổi thành IP máy chạy backend.

Kiểm tra mã nguồn và test:

```powershell
cd D:\Buidoananhviet\app
flutter analyze
flutter test                      # 128 test; 6 test tích hợp tự bỏ qua nếu thiếu biến môi trường dưới đây
# Chạy cả test tích hợp với backend thật: nên dùng DB TẠM (không đụng dữ liệu đang dùng), xem bên dưới
$env:TG_BASE_URL = "http://localhost:5099"
$env:TG_ADMIN_PW = "<mật khẩu admin của DB tạm>"
flutter test
```

> Các test tích hợp tạo dữ liệu thật (nhân viên, ca, chấm công) nên **đừng chạy trên DB đang dùng**. Cách chạy trên DB tạm:
> ```powershell
> $env:ConnectionStrings__DefaultConnection = "Server=(localdb)\MSSQLLocalDB;Database=Buidoananhviet_it;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=true"
> $env:Otp__DevMode = "true"; $env:Urls = "http://0.0.0.0:5099"
> cd D:\Buidoananhviet\backend\Buidoananhviet.Api
> dotnet run --no-build                      # (cửa sổ 1) tạo DB tạm + migration + 5 ca
> # đăng ký tài khoản admin tạm qua Swagger/API (username admin, email admin@timeguard.local), rồi:
> dotnet run --no-build -- --make-admin admin@timeguard.local
> # chạy lại backend, chạy test trỏ vào cổng 5099, xong thì xóa DB: DROP DATABASE [Buidoananhviet_it]
> ```
> Test backend (không cần DB thật, dùng DB trong bộ nhớ): `cd D:\Buidoananhviet\backend\Buidoananhviet.Api.Tests; dotnet test` (47 test: ca 24:00, QR cố định, không chấm 2 ca, dữ liệu mẫu nhất quán, lệnh quản trị).

## 4. Tài khoản, ca làm, mã QR, lệnh quản trị

### Tài khoản
Backend **không tự tạo user** khi khởi động. DB hiện giữ đúng 1 admin (`admin` / `admin@timeguard.local`, mật khẩu cũ của bạn) và 5 nhân viên mẫu do `--reset-demo` nạp (mật khẩu = `Seed:EmployeePassword` trong `appsettings.Development.json`):

| Nhân viên | Username | Email nhận OTP | Ca | Lương/giờ |
|---|---|---|---|---|
| Nguyễn Thị Lan Anh | `lananh` | `<EmailBase>+lananh@gmail.com` | Ca 1 | 35.000 |
| Trần Minh Quân | `minhquan` | `<EmailBase>+minhquan@gmail.com` | Ca 2 | 38.000 |
| Lê Hoàng Nam | `hoangnam` | `<EmailBase>+hoangnam@gmail.com` | Ca 3 (đêm) | 42.000 |
| Phạm Thu Hà | `thuha` | `<EmailBase>+thuha@gmail.com` | Ca gãy sáng + Ca gãy chiều | 32.000 |
| Võ Quốc Bảo | `quocbao` | `<EmailBase>+quocbao@gmail.com` | Ca 1 | 30.000 |

Đăng nhập: email hoặc tên đăng nhập + mật khẩu, rồi **OTP gửi qua email** (với `Otp:DevMode=true` thì bấm **Tự điền** hoặc xem console). **Đăng ký** (tên đăng nhập tùy chọn, bỏ trống = phần trước `@`) cũng gửi OTP xác thực email; đăng ký luôn ra nhân viên.

### 5 ca cố định và mã QR cố định
Đồng bộ lúc khởi động theo TÊN ca (idempotent). Hai ca seed cũ được đổi tên/giờ thành Ca 1, Ca 2 (giữ Id); ca rác do test tạo (tên bắt đầu `Ca ET`, `Ca RP`, `Ca UI test`...) bị xóa nếu chưa có chấm công. Khởi động lại **không đổi** mã QR.

| Ca | Giờ (UTC+7) | Mã QR / mã gõ tay | Ảnh PNG |
|---|---|---|---|
| Ca 1 | 06:00 - 12:00 | `TG-CA1-KJJ446CX` | `qr\QR_Ca1.png` |
| Ca 2 | 12:00 - 18:00 | `TG-CA2-E7U48ZW8` | `qr\QR_Ca2.png` |
| Ca 3 | 18:00 - 24:00 | `TG-CA3-TV5FDGX8` | `qr\QR_Ca3.png` |
| Ca gãy sáng | 05:00 - 09:00 | `TG-GAYS-ZGT7Q99U` | `qr\QR_Ca_gay_sang.png` |
| Ca gãy chiều | 16:00 - 20:00 | `TG-GAYC-JSRSED2A` | `qr\QR_Ca_gay_chieu.png` |

Cả 5 mã trên một tờ A4: `qr\QR_tong_hop.png`. Nội dung QR = đúng mã ở bảng (không tiền tố/JSON). Tạo lại ảnh: `python D:\Buidoananhviet\qr\tao_qr.py` (cần `pip install qrcode pillow opencv-python`); kiểm tra ảnh giải mã đúng và khớp DB: `python D:\Buidoananhviet\qr\tao_qr.py --verify`. Nút **Đổi mã QR** của admin vẫn dùng được nhưng khi đổi thì PNG cũ hết hiệu lực (đồng bộ khởi động sẽ ép mã về giá trị cố định ở trên).

Giờ kết thúc **24:00** được lưu thành `23:59:59.9999999` (cột SQL `time` không chứa được 24:00) và luôn hiển thị là `24:00`; nhập `24:00` qua API được. Ca 3 check-out sau 00:00 vẫn được (bản ghi thuộc ngày làm việc hôm trước, giờ làm tính tới 24:00).

### Quy tắc chấm công liên quan đến ca
- Các ca **chồng giờ** nhau là chủ ý (mã QR quyết định ca). Mỗi nhân viên chấm 1 lần/ca/ngày.
- **Không chấm 2 ca cùng lúc**: đang có ca đã check-in mà chưa check-out (còn trong giờ của ca đó) thì check-in ca khác bị từ chối `409` ("Bạn đang trong <tên ca> chưa check-out. Hãy check-out ca đó trước khi chấm ca khác."), không lưu gì. Sau khi check-out thì chấm ca khác bình thường. Ca đã quá giờ mà quên check-out **không** chặn ca sau (admin dùng "Đóng ca"). Trên app: ca khác hiện mờ kèm dòng "Đang trong <tên ca> chưa check-out".

### Lệnh quản trị (chỉ Development, chạy rồi thoát, không mở web host)
```powershell
cd D:\Buidoananhviet\backend\Buidoananhviet.Api
dotnet run -- --reset-demo                 # XÓA chấm công, nghỉ phép, mọi user trừ "admin"; giữ cấu hình + 5 ca + QR; nạp 5 nhân viên mẫu
dotnet run -- --make-admin  <email>        # đặt role admin theo email (không phân biệt hoa thường)
dotnet run -- --make-employee <email>      # đặt role nhân viên
```
`--reset-demo` in rõ sẽ xóa gì, rồi bảng tóm tắt trước/sau, 5 ca và số liệu từng nhân viên. **Phá hủy dữ liệu**: sao lưu trước nếu cần (`BACKUP DATABASE [Buidoananhviet] TO DISK='...'`). Sau `--make-admin/--make-employee` phải **ĐĂNG XUẤT rồi đăng nhập lại** trong app (vai trò nằm trong JWT). Quy trình đổi admin: đăng ký tài khoản mới -> `--make-admin <email>` -> đăng nhập lại -> dùng tài khoản mới xóa admin cũ ở tab Nhân viên.

### Dữ liệu mẫu (nạp bởi `--reset-demo`)
Lịch sử từ 14/09/2026 đến hôm nay (thứ Hai-thứ Bảy, nghỉ Chủ nhật), vị trí cách công ty 0-60 m, giờ vào/ra lệch tự nhiên; 9 đơn nghỉ phép (chờ duyệt, đã duyệt, từ chối); các tình huống: Quân 1 lần quên check-out được admin đóng ca, Nam 1 lần ra sớm, Hà làm 2 ca gãy cùng ngày và nghỉ 2 ngày, Bảo hay đi trễ với 2 ca nghi ngờ (1 đã gỡ cờ, 1 còn treo) và hôm nay quên check-out Ca 1. Mọi bản ghi được tạo bằng chính `AttendanceService` (đồng hồ giả lập) nên giờ làm, phạt, lương, trạng thái đúng quy tắc server. Hôm nay chỉ có ca đã bắt đầu tại thời điểm chạy lệnh; ca đang diễn ra để "đang làm".

Vị trí công ty `10.7769, 106.7009`, bán kính 100 m, phạt 1.000 đ/phút trễ (ân hạn 5 phút/ca).

## 5. Checklist demo trên máy ảo Android

Các lệnh `adb` (ở `D:\Android-SDK\platform-tools\adb.exe`):

1. **Backend chạy**, app gọi được `http://10.0.2.2:5000` (mở Chrome trên máy ảo vào địa chỉ đó + `/api/health` để thử).
2. **Camera trước = webcam laptop**: khởi động máy ảo bằng `emulator -avd Pixel_6 -camera-front webcam0 -camera-back virtualscene` (camera sau dùng quét QR ảo, camera trước dùng xác thực mặt). Cấp quyền camera + vị trí cho app; đặt GPS ảo `adb emu geo fix 106.7009 10.7769`.
3. **Đặt GPS giả đúng tọa độ công ty**: Extended controls (`...`) -> Location -> nhập `10.7769`, `106.7009` -> Set location; hoặc `adb emu geo fix 106.7009 10.7769` (lưu ý: **kinh độ trước, vĩ độ sau**). Gặp hộp thoại Google "Location Accuracy" thì chọn **Turn on**, rồi gửi lại tọa độ.
4. **Chọn ca đang trong giờ** (có sẵn 5 ca cố định, mục 4): ví dụ 18:00-24:00 dùng Ca 3. Chấm công mở từ 30 phút trước giờ ca đến hết ca (check-out thì không giới hạn giờ). Dùng mã gõ tay hoặc ảnh PNG trong `qr\`.
5. **Quyền**: lần đầu app xin quyền **vị trí** (While using the app) và **camera**.
6. **Quét QR**: admin mở **Ca làm -> chạm vào ca** để thấy QR to (chứa `qrToken`) và **mã nhập tay** (có nút sao chép).
   - Camera ảo: Extended controls -> Camera -> Virtual scene, hoặc dùng webcam máy tính; đưa QR hiển thị trên màn hình máy tính vào camera.
   - **Nếu camera lỗi / từ chối quyền** app tự chuyển sang ô **Nhập mã tay** (kiểm chứng: bấm *Don't allow* ở hộp thoại camera).
7. **Chấm công** (đăng nhập một nhân viên mẫu, vd. `lananh`; OTP về email `<EmailBase>+lananh@...`): Hôm nay -> **Chấm công** -> chọn ca -> **1. Quét QR** (hoặc nhập mã tay; từ chối camera thì tự chuyển nhập tay) -> **2. Vị trí** (GPS) -> **3. Khuôn mặt**: nhìn thẳng, mặt bình thường; rồi làm 2 việc ngẫu nhiên trong {Cười, Quay đầu sang trái, Quay đầu sang phải} (mỗi việc 10 giây, hết giờ thì bấm Thử lại). Cười tươi lộ răng (ngưỡng 0,7), quay đầu rõ khoảng 20-30°. Nếu hướng trái/phải bị ngược trên máy bạn, đổi `AppConfig.faceLeftIsPositiveYaw`. Nút **Bỏ qua (chỉ để demo)** hiện khi `AppConfig.allowSkipFace` (mặc định bật ở debug) và gửi `faceVerified=false` (không bị đánh dấu nghi ngờ). Chấm công lần nữa để **ra ca**.
8. **Thử cờ nghi ngờ**:
   - Cách 1: bật *Mock location*: Settings -> About -> bấm 7 lần Build number -> Developer options -> *Select mock location app* (cần một ứng dụng mock location) rồi chấm công; app hiện cảnh báo "GPS giả" và ca bị đánh dấu **Nghi ngờ**.
   - Cách 2: đăng nhập 2 nhân viên khác nhau trên **cùng một máy** trong cùng ngày: người thứ hai bị đánh dấu nghi ngờ (cùng `deviceId`).
   - Có sẵn 2 ca nghi ngờ của Võ Quốc Bảo trong dữ liệu mẫu (1 đã gỡ cờ, 1 còn treo để demo **Xử lý**).
   - **Thử không chấm 2 ca cùng lúc**: check-in Ca gãy sáng (05:00-09:00) rồi check-in Ca 1 (06:00-12:00) khi chưa check-out -> bị từ chối; ca kia hiện mờ trên tab Hôm nay.
9. **Admin xử lý**: tab **Báo cáo** -> banner **Xử lý** (hoặc *Quản lý chấm công*) -> **Gỡ cờ nghi ngờ** / **Đóng ca** cho bản ghi quên check-out.
10. **Giao diện sáng/tối**: `adb shell cmd uimode night yes` (tối) / `no` (sáng). Biểu đồ ở tab **Báo cáo** (admin) và **Lịch sử** (nhân viên).
11. **Hết phiên**: JWT hết hạn hoặc server trả 401 thì app tự xóa token và quay về màn đăng nhập.

## 6. Khắc phục sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| App báo "Không kết nối được máy chủ" | Backend chưa chạy hoặc chưa nghe `0.0.0.0:5000`; thiết bị thật phải đổi `baseUrl`; kiểm tra tường lửa Windows cho cổng 5000 |
| Lỗi LocalDB khi `dotnet run` | `sqllocaldb start MSSQLLocalDB`; kiểm tra chuỗi kết nối |
| `Jwt:Key chưa cấu hình` | Chạy với `ASPNETCORE_ENVIRONMENT=Development` (mặc định khi `dotnet run` qua launchSettings) hoặc đặt `Jwt__Key` |
| Màn khuôn mặt báo lỗi camera / đen | Kiểm tra quyền camera, khởi động máy ảo với `-camera-front webcam0` (mục 5.2), bấm Thử lại |
| Chờ GPS lâu rồi báo "Không lấy được vị trí" | Gửi lại `adb emu geo fix ...`, bật *Location Accuracy*, bấm **Thử lại** |
| Chấm công báo "vượt bán kính" | GPS máy ảo xa công ty: đặt lại đúng tọa độ, hoặc admin đổi vị trí ở tab **Cấu hình** (nút *Lấy vị trí hiện tại*) |
| Chấm công báo "Chưa tới giờ check-in / Ca đã kết thúc" | Chọn ca đang trong giờ (giờ Việt Nam) trong 5 ca cố định, hoặc admin chỉnh giờ ca |
| Chấm công báo "Bạn đang trong <ca> chưa check-out" | Check-out ca đang mở trước (quên check-out và ca đã quá giờ thì không bị chặn; admin dùng "Đóng ca") |
| `--make-admin` báo không tìm thấy | Kiểm tra đúng email (không phân biệt hoa thường) và đang chạy ở Development |

## 7. Lưu ý khi triển khai thật

Đây là bản demo: `Otp:DevMode` lộ OTP trên màn hình, HTTP không mã hóa (`usesCleartextTraffic` bật), endpoint `GET /api/Authenticate/admin-check` chỉ để kiểm tra phân quyền. Khi triển khai: tắt `Otp:DevMode` và cấu hình SMTP, dùng HTTPS, tắt cleartext, đặt `Jwt:Key` bằng biến môi trường.

## Giao diện
Font **Be Vietnam Pro** được nhúng sẵn trong `app/assets/fonts` (chạy offline, không cần tải). Giao diện tự đổi sáng/tối theo hệ thống (`adb shell cmd uimode night yes|no` để thử trên máy ảo).
