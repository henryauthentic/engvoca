# Ứng dụng Học Từ Vựng Tiếng Anh

Một ứng dụng học từ vựng đa nền tảng hiện đại được xây dựng bằng Flutter. Ứng dụng được thiết kế để giúp người dùng làm chủ từ vựng tiếng Anh thông qua các chế độ học tập tương tác, game hóa sinh động và các tính năng trò chuyện AI thông minh.

## 🚀 Các Tính Năng Nổi Bật

*   **Hỗ trợ Đa Nền Tảng**: Hoạt động mượt mà trên cả Mobile (iOS/Android) và Web với giao diện hiển thị thích ứng (responsive).
*   **Kiến trúc Cơ Sở Dữ Liệu Lai (Hybrid Database)**: 
    *   **Mobile**: Sử dụng SQLite cục bộ (`sqflite`) với cơ sở dữ liệu có sẵn giúp học offline và truy xuất cực nhanh.
    *   **Web**: Tích hợp Cloud Firestore, sử dụng export có điều kiện để đảm bảo tương thích trên web mà không ảnh hưởng tới core của mobile.
*   **Xác thực Tài Khoản**: Đăng nhập và quản lý người dùng an toàn với Firebase Authentication và Google Sign-In.
*   **Chat với AI Thông Minh**: Luyện tập kỹ năng giao tiếp tiếng Anh bằng AI tạo sinh với Gemini API (`google_generative_ai`).
*   **Các Chế Độ Học Tập Tương Tác**: 
    *   **Thẻ Ghi Nhớ (Flashcards)**: Flashcard hiện đại, kết hợp hiệu ứng Lottie giúp ghi nhớ nhanh.
    *   **Luyện Tập (Practice)**: Các bài tập trắc nghiệm và ôn luyện kết hợp hiệu ứng âm thanh tùy chỉnh sau mỗi câu trả lời (`audioplayers`).
    *   **Ôn Tập (Review)**: Theo dõi tiến độ học tập và ôn tập ngắt quãng giúp nhớ lâu.
*   **Chuyển Văn Bản thành Giọng Nói (TTS)**: Hỗ trợ đọc phát âm chuẩn bản xứ sử dụng `flutter_tts`, giúp người dùng học cách phát âm chính xác từ vựng.
*   **Game Hóa (Gamification)**: Tăng tương tác người dùng qua các hiệu ứng động đẹp mắt (`lottie`, `flutter_animate`) và theo dõi tiến độ học với các biểu đồ trực quan (`fl_chart`).
*   **Nhắc Nhở Học Tập Hàng Ngày**: Thông báo thông minh có thể tùy chỉnh (`flutter_local_notifications`) tự động nhắc nhở người dùng theo mục tiêu hằng ngày.
*   **Tùy Chỉnh Hồ Sơ**: Người dùng có thể cá nhân hóa tài khoản bằng ảnh đại diện tùy thích (`image_picker`, `image_cropper`).

## 🛠 Công Nghệ Sử Dụng

*   **Framework:** [Flutter](https://flutter.dev/) (SDK >= 3.0)
*   **Quản lý Trạng Thái (State Management):** `provider`
*   **Cơ Sở Dữ Liệu:**
    *   Mobile: `sqflite` (Local)
    *   Sync/Web: Firebase Firestore (Cloud)
*   **Dịch Vụ Backend:** Firebase Auth
*   **Tích hợp AI:** Google Generative AI (Gemini)
*   **UI/UX:** `lottie`, `flutter_animate`, `google_fonts`, `fl_chart`, `cupertino_icons`

## 📁 Cấu Trúc Dự Án

```text
lib/
├── models/         # Các model và cấu trúc dữ liệu
├── providers/      # Logic quản lý tài nguyên và trạng thái ứng dụng
├── screens/        # Giao diện ứng dụng (Flashcard, Practice, Review, AI Chat, v.v.)
├── services/       # Xử lý gọi API / Tương tác ngoại vi (Database, Firebase, AI, Gamification)
├── widgets/        # Các UI component tái sử dụng (AppCard, PrimaryButton, v.v.)
└── main.dart       # Điểm khởi chạy của ứng dụng
```

## ⚙️ Hướng Dẫn Cài Đặt

### Yêu Cầu Hệ Thống
*   Đã cài đặt [Flutter SDK](https://flutter.dev/docs/get-started/install)
*   Một IDE phù hợp (VS Code, Android Studio, IntelliJ)
*   Dự án Firebase đã được cấu hình (để xác thực và lưu trữ dữ liệu web)
*   Google Gemini API Key (được dùng để sử dụng AI)

### Các Bước Thực Hiện

1.  **Clone dự án:**
    ```bash
    git clone <your-repository-url>
    cd vocabulary_app_v2
    ```

2.  **Cài đặt các thư viện:**
    ```bash
    flutter pub get
    ```

3.  **Chạy trên Mobile / Emulator:**
    ```bash
    flutter run
    ```
    
4.  **Chạy trên Web:**
    ```bash
    flutter run -d chrome
    ```

## 📸 Hình Ảnh Ứng Dụng
*(Bạn có thể thay thế các link dưới đây bằng ảnh chụp màn hình dự án của mình)*

```markdown
![Màn hình DashBoard](<img width="514" height="1075" alt="image" src="https://github.com/user-attachments/assets/01fca8fc-3940-4191-8297-f4e2eec12896" />
)   ![Tính năng Flashcards](<img width="510" height="1065" alt="image" src="https://github.com/user-attachments/assets/ad8044b1-5bb4-46b4-91a8-863b3bcd3a54" />
)   ![Chat AI](<img width="515" height="1063" alt="image" src="https://github.com/user-attachments/assets/c1dbcca9-21c3-47d8-93f2-398b75290b98" />
)
```
