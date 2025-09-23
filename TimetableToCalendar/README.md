# FAP-ICS-Export — Export lịch môn từ FAP (ViewAttendstudent) ra .ics

> Một bookmarklet / userscript nhỏ để convert bảng lịch trên `https://fap.fpt.edu.vn/Report/ViewAttendstudent.aspx` thành file `.ics` xài cho Google Calendar / Outlook / Apple Calendar.
> Nhỏ — nhưng hữu ích. Giống mì gói lúc đói: nhanh, no, ngon. 😎


## Tóm tắt nhanh

* Script đọc bảng `.table1` trên trang **ViewAttendstudent** của FAP, parse ngày, khung giờ, phòng, giảng viên, nhóm, rồi xuất 1 file `.ics`.
* Hỗ trợ timezone `Asia/Ho_Chi_Minh` (GMT+7).
* Chỉ chạy **khi bạn đã ở trang** `https://fap.fpt.edu.vn/Report/ViewAttendstudent.aspx`.
* Xuất file tên dựa trên mã môn / tên môn (được sanitize để hợp lệ trên file system).

## Tính năng

* Export hàng loạt buổi học thành chuẩn iCalendar (.ics).
* Tự động extract: ngày, giờ bắt đầu/kết thúc, phòng, giảng viên, group.
* Tên file được làm sạch để không bị lỗi ký tự.
* Dùng trực tiếp từ console hoặc gán làm bookmarklet / userscript.

## Cách dùng (quickstart)

### 1) Dùng trực tiếp (Console)

1. Truy cập: `https://fap.fpt.edu.vn/Report/ViewAttendstudent.aspx`
2. Chọn một môn trong cột **Course** (script yêu cầu chọn 1 môn).
3. Mở DevTools → tab **Console**.
4. Dán toàn bộ script (phần bạn đã gửi) vào console và Enter.
5. File `.ics` sẽ được tải xuống tự động. Console sẽ log: `Exported N events. File: <tên file>`.

### 2) Tạo Bookmarklet (1-click)

1. Tạo bookmark mới trong trình duyệt.
2. Đặt tên ví dụ: `FAP → ICS`.****
3. Ở URL dán **toàn bộ** script nhưng bỏ `javascript:` prefix nếu trình duyệt yêu cầu hoặc giữ nguyên tuỳ trình duyệt.
   Ví dụ URL:

   ```
   javascript:(()=>{ /* ...toàn bộ script... */ })();
   ```
4. Truy cập trang ViewAttendstudent → chọn môn → click bookmarklet → file .ics được tải về.

> Lưu ý: nếu paste vào thanh địa chỉ có giới hạn ký tự, hãy dùng userscript manager (Tampermonkey / Violentmonkey) hoặc tạo một extension snippet.

## Ví dụ output

* Tên file: `INT123.ics` hoặc `Introduction to Networking.ics` (tùy tìm được course code hay không).
* Mở file bằng Google Calendar: Import → Chọn file → Xong.

## Giải thích nhanh cách hoạt động (technical)

* Script tìm phần tử course đã chọn trong `#ctl00_mainContent_divCourse`.
* Lấy các hàng `table.table1 tbody tr` có >= 7 cột (cấu trúc UI hiện tại).
* Parse:

  * `td[1]` = date (`dd/mm/yyyy`)
  * `td[2]` = slot (chứa `(HH:MM - HH:MM)`)
  * `td[3]` = room
  * `td[4]` = lecturer
  * `td[5]` = group
* Sinh UID, SUMMARY, LOCATION, DESCRIPTION và xuất .ics với VTIMEZONE `Asia/Ho_Chi_Minh`.

## Những lỗi thường gặp & cách fix

* **Script báo: "Hãy chọn 1 môn..."**
  → Bạn chưa chọn course ở cột Course. Chọn 1 dòng môn rồi chạy lại.
* **Không tìm thấy hàng lịch** (`Không tìm thấy hàng lịch trong bảng .table1.`)
  → Cấu trúc trang có thể khác: kiểm tra class của bảng hoặc xem có đang ở trang đúng không.
* **Không parse được slot giờ**
  → Nếu khung giờ hiển thị khác format `(HH:MM - HH:MM)`, script sẽ fail. Cần chỉnh regex `slotText.match(...)`.
* **Tên file bị lỗi ký tự**
  → Script đã sanitize; tuy nhiên nếu tên quá dài/đặc biệt hãy đổi thủ công.


## Tuỳ chỉnh nhanh (developer)

* Thay timezone: sửa `TZID` ở đầu script.
* Muốn thêm alarm/reminder? Thêm `BEGIN:VALARM` block vào mỗi VEVENT trước `END:VEVENT`.
* Muốn chọn chỉ các rows của 1 nhóm cụ thể? Lọc `rows` bằng `td[5]`.


## Security & Privacy

* Script chạy **chỉ trên client**, không gửi dữ liệu ra server.
* Dữ liệu lịch chỉ tạo thành file `.ics` trên máy bạn.
* Không chịu trách nhiệm nếu website FAP thay DOM dẫn tới parse sai — tự do fork & sửa nhé.


## Contributing

* Gặp bug? Tạo issue / PR trên repo.
* Muốn thêm tính năng: examples/preview, support multiple pages, chọn nhiều môn, or Google Calendar API auto-upload — PR welcome.
* Coding style: simple JS, no deps. Giữ nhẹ, dễ paste vào console.