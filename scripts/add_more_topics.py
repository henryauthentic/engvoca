"""
Script thêm topic & từ vựng mới vào EnglishMaster_cleaned.db
Chạy: python scripts/add_more_topics.py
"""
import sqlite3
import uuid
import sys

sys.stdout.reconfigure(encoding='utf-8')

DB_PATH = 'assets/database/EnglishMaster_cleaned.db'

def gen_id():
    return str(uuid.uuid4())

# ══════════════════════════════════════════════════════════
# DATA MỚI
# ══════════════════════════════════════════════════════════

NEW_DATA = {
    # ── Parent: Business English ──
    "Business English": {
        "order_index": 14,
        "icon_url": "💼",
        "color_hex": "#E67E22",
        "description": "Từ vựng tiếng Anh thương mại và giao dịch",
        "children": {
            "Meetings & Presentations": [
                ("agenda", "n", "chương trình nghị sự", "Let's review the agenda before the meeting.", "Hãy xem lại chương trình trước cuộc họp."),
                ("brainstorm", "v", "động não, suy nghĩ sáng tạo", "Let's brainstorm ideas for the new product.", "Hãy cùng brainstorm ý tưởng cho sản phẩm mới."),
                ("deadline", "n", "hạn chót", "The deadline for this project is Friday.", "Hạn chót cho dự án này là thứ Sáu."),
                ("feedback", "n", "phản hồi", "I appreciate your feedback on my presentation.", "Tôi trân trọng phản hồi của bạn về bài thuyết trình."),
                ("minutes", "n", "biên bản họp", "Who is taking the minutes today?", "Ai ghi biên bản họp hôm nay?"),
                ("proposal", "n", "đề xuất", "The proposal was approved by management.", "Đề xuất đã được ban quản lý phê duyệt."),
                ("stakeholder", "n", "bên liên quan", "All stakeholders should be informed.", "Tất cả các bên liên quan cần được thông báo."),
                ("milestone", "n", "cột mốc quan trọng", "We reached an important milestone this quarter.", "Chúng tôi đạt cột mốc quan trọng quý này."),
                ("objective", "n", "mục tiêu", "Our main objective is to increase revenue.", "Mục tiêu chính là tăng doanh thu."),
                ("strategy", "n", "chiến lược", "We need a new marketing strategy.", "Chúng ta cần chiến lược marketing mới."),
                ("negotiate", "v", "đàm phán", "We need to negotiate the contract terms.", "Chúng ta cần đàm phán các điều khoản hợp đồng."),
                ("collaborate", "v", "cộng tác", "Teams should collaborate more effectively.", "Các nhóm nên cộng tác hiệu quả hơn."),
                ("delegate", "v", "ủy quyền, giao việc", "Learn to delegate tasks to your team.", "Học cách giao việc cho nhóm của bạn."),
                ("facilitate", "v", "hỗ trợ, tạo điều kiện", "She will facilitate the workshop.", "Cô ấy sẽ điều phối buổi workshop."),
                ("implement", "v", "triển khai, thực hiện", "We will implement the plan next month.", "Chúng tôi sẽ triển khai kế hoạch tháng sau."),
            ],
            "Finance & Banking": [
                ("investment", "n", "đầu tư", "Real estate is a good long-term investment.", "Bất động sản là khoản đầu tư dài hạn tốt."),
                ("revenue", "n", "doanh thu", "The company's revenue grew by 15%.", "Doanh thu công ty tăng 15%."),
                ("profit", "n", "lợi nhuận", "Net profit increased significantly.", "Lợi nhuận ròng tăng đáng kể."),
                ("budget", "n", "ngân sách", "We need to stay within budget.", "Chúng ta cần giữ trong ngân sách."),
                ("invoice", "n", "hóa đơn", "Please send the invoice by email.", "Vui lòng gửi hóa đơn qua email."),
                ("transaction", "n", "giao dịch", "All transactions are recorded.", "Tất cả giao dịch đều được ghi nhận."),
                ("mortgage", "n", "thế chấp", "They took out a mortgage for their house.", "Họ vay thế chấp để mua nhà."),
                ("interest rate", "n", "lãi suất", "The interest rate is currently 5%.", "Lãi suất hiện tại là 5%."),
                ("dividend", "n", "cổ tức", "Shareholders received a quarterly dividend.", "Cổ đông nhận cổ tức hàng quý."),
                ("asset", "n", "tài sản", "The company has significant assets.", "Công ty có tài sản đáng kể."),
                ("liability", "n", "nợ phải trả", "Current liabilities include short-term debts.", "Nợ ngắn hạn bao gồm các khoản vay ngắn hạn."),
                ("equity", "n", "vốn chủ sở hữu", "The equity ratio has improved.", "Tỷ lệ vốn chủ sở hữu đã cải thiện."),
                ("inflation", "n", "lạm phát", "Inflation affects purchasing power.", "Lạm phát ảnh hưởng đến sức mua."),
                ("recession", "n", "suy thoái", "The economy entered a recession.", "Nền kinh tế rơi vào suy thoái."),
                ("stock market", "n", "thị trường chứng khoán", "The stock market crashed yesterday.", "Thị trường chứng khoán sụp đổ hôm qua."),
            ],
            "Email & Communication": [
                ("attachment", "n", "tệp đính kèm", "Please find the report in the attachment.", "Vui lòng xem báo cáo trong tệp đính kèm."),
                ("regarding", "prep", "liên quan đến", "I'm writing regarding your application.", "Tôi viết thư liên quan đến đơn ứng tuyển của bạn."),
                ("sincerely", "adv", "trân trọng", "Yours sincerely, John Smith.", "Trân trọng, John Smith."),
                ("cc", "v", "gửi bản sao", "Please cc me on the email.", "Vui lòng cc tôi trong email."),
                ("forward", "v", "chuyển tiếp", "Could you forward this to the team?", "Bạn có thể chuyển tiếp cho nhóm không?"),
                ("acknowledge", "v", "xác nhận", "Please acknowledge receipt of this email.", "Vui lòng xác nhận đã nhận email."),
                ("apologize", "v", "xin lỗi", "I apologize for the inconvenience.", "Tôi xin lỗi vì sự bất tiện."),
                ("confirm", "v", "xác nhận", "I'd like to confirm our meeting tomorrow.", "Tôi muốn xác nhận cuộc họp ngày mai."),
                ("inquiry", "n", "yêu cầu thông tin", "Thank you for your inquiry.", "Cảm ơn bạn đã gửi yêu cầu."),
                ("correspondence", "n", "thư từ, trao đổi", "Please keep records of all correspondence.", "Vui lòng lưu tất cả thư từ trao đổi."),
            ],
        },
    },

    # ── Parent: Technology & IT ──
    "Technology & IT": {
        "order_index": 15,
        "icon_url": "💻",
        "color_hex": "#2980B9",
        "description": "Từ vựng công nghệ thông tin hiện đại",
        "children": {
            "Software Development": [
                ("algorithm", "n", "thuật toán", "This algorithm sorts data efficiently.", "Thuật toán này sắp xếp dữ liệu hiệu quả."),
                ("database", "n", "cơ sở dữ liệu", "We store user data in a database.", "Chúng tôi lưu dữ liệu người dùng trong cơ sở dữ liệu."),
                ("debug", "v", "gỡ lỗi", "I need to debug this code.", "Tôi cần gỡ lỗi đoạn code này."),
                ("deploy", "v", "triển khai", "We'll deploy the update tonight.", "Chúng tôi sẽ triển khai bản cập nhật tối nay."),
                ("framework", "n", "khung làm việc", "Flutter is a popular mobile framework.", "Flutter là framework mobile phổ biến."),
                ("repository", "n", "kho lưu trữ", "Push your code to the repository.", "Đẩy code lên kho lưu trữ."),
                ("compile", "v", "biên dịch", "The code failed to compile.", "Code không biên dịch được."),
                ("iterate", "v", "lặp lại", "We iterate over the array.", "Chúng ta lặp qua mảng."),
                ("refactor", "v", "tái cấu trúc", "We should refactor this module.", "Chúng ta nên tái cấu trúc module này."),
                ("optimize", "v", "tối ưu hóa", "Optimize the query for better performance.", "Tối ưu hóa truy vấn để hiệu suất tốt hơn."),
                ("interface", "n", "giao diện", "The user interface is intuitive.", "Giao diện người dùng trực quan."),
                ("bug", "n", "lỗi phần mềm", "We found a critical bug.", "Chúng tôi tìm thấy lỗi nghiêm trọng."),
                ("API", "n", "giao diện lập trình ứng dụng", "The API returns JSON data.", "API trả về dữ liệu JSON."),
                ("backend", "n", "phần phụ trợ", "The backend handles authentication.", "Backend xử lý xác thực."),
                ("frontend", "n", "giao diện người dùng", "She works as a frontend developer.", "Cô ấy làm lập trình viên frontend."),
            ],
            "Artificial Intelligence": [
                ("machine learning", "n", "học máy", "Machine learning powers many modern apps.", "Học máy vận hành nhiều ứng dụng hiện đại."),
                ("neural network", "n", "mạng nơ-ron", "Neural networks mimic the human brain.", "Mạng nơ-ron mô phỏng bộ não con người."),
                ("training data", "n", "dữ liệu huấn luyện", "We need more training data.", "Chúng ta cần thêm dữ liệu huấn luyện."),
                ("prediction", "n", "dự đoán", "The model makes accurate predictions.", "Mô hình đưa ra dự đoán chính xác."),
                ("automation", "n", "tự động hóa", "Automation reduces manual work.", "Tự động hóa giảm công việc thủ công."),
                ("chatbot", "n", "trợ lý ảo", "The chatbot answers customer questions.", "Chatbot trả lời câu hỏi khách hàng."),
                ("natural language", "n", "ngôn ngữ tự nhiên", "NLP processes natural language.", "NLP xử lý ngôn ngữ tự nhiên."),
                ("deep learning", "n", "học sâu", "Deep learning requires massive datasets.", "Học sâu cần tập dữ liệu khổng lồ."),
                ("pattern recognition", "n", "nhận dạng mẫu", "AI excels at pattern recognition.", "AI xuất sắc trong nhận dạng mẫu."),
                ("generative AI", "n", "AI tạo sinh", "Generative AI can create images.", "AI tạo sinh có thể tạo hình ảnh."),
            ],
            "Cybersecurity": [
                ("encryption", "n", "mã hóa", "Data is protected by encryption.", "Dữ liệu được bảo vệ bằng mã hóa."),
                ("firewall", "n", "tường lửa", "The firewall blocks unauthorized access.", "Tường lửa chặn truy cập trái phép."),
                ("phishing", "n", "lừa đảo trực tuyến", "Be careful of phishing emails.", "Cẩn thận với email lừa đảo."),
                ("malware", "n", "phần mềm độc hại", "The system was infected with malware.", "Hệ thống bị nhiễm phần mềm độc hại."),
                ("vulnerability", "n", "lỗ hổng bảo mật", "We discovered a security vulnerability.", "Chúng tôi phát hiện lỗ hổng bảo mật."),
                ("authentication", "n", "xác thực", "Two-factor authentication is recommended.", "Xác thực hai yếu tố được khuyến nghị."),
                ("breach", "n", "vi phạm, xâm nhập", "A data breach exposed user accounts.", "Vụ xâm nhập làm lộ tài khoản người dùng."),
                ("ransomware", "n", "mã độc tống tiền", "Ransomware encrypts your files.", "Mã độc tống tiền mã hóa tệp của bạn."),
                ("backup", "n", "sao lưu", "Always maintain regular backups.", "Luôn duy trì sao lưu thường xuyên."),
                ("password", "n", "mật khẩu", "Use a strong password.", "Sử dụng mật khẩu mạnh."),
            ],
        },
    },

    # ── Parent: Academic & Study ──
    "Academic English": {
        "order_index": 16,
        "icon_url": "🎓",
        "color_hex": "#8E44AD",
        "description": "Từ vựng học thuật dùng trong nghiên cứu và trình bày",
        "children": {
            "Research & Writing": [
                ("hypothesis", "n", "giả thuyết", "The hypothesis was proven correct.", "Giả thuyết đã được chứng minh đúng."),
                ("thesis", "n", "luận văn", "She submitted her thesis last week.", "Cô ấy nộp luận văn tuần trước."),
                ("abstract", "n", "tóm tắt", "Read the abstract before the full paper.", "Đọc tóm tắt trước khi đọc bài viết đầy đủ."),
                ("bibliography", "n", "danh mục tài liệu", "Include a bibliography at the end.", "Thêm danh mục tài liệu ở cuối."),
                ("citation", "n", "trích dẫn", "Proper citations are important.", "Trích dẫn đúng cách rất quan trọng."),
                ("methodology", "n", "phương pháp luận", "The methodology section explains how.", "Phần phương pháp luận giải thích cách thức."),
                ("peer review", "n", "đánh giá đồng nghiệp", "The paper went through peer review.", "Bài báo đã qua đánh giá đồng nghiệp."),
                ("plagiarism", "n", "đạo văn", "Plagiarism is a serious offense.", "Đạo văn là vi phạm nghiêm trọng."),
                ("analysis", "n", "phân tích", "The data analysis shows a clear trend.", "Phân tích dữ liệu cho thấy xu hướng rõ ràng."),
                ("conclusion", "n", "kết luận", "The conclusion summarizes key findings.", "Kết luận tóm tắt các phát hiện chính."),
                ("literature review", "n", "tổng quan tài liệu", "The literature review covers 50 papers.", "Tổng quan tài liệu bao gồm 50 bài báo."),
                ("qualitative", "adj", "định tính", "We used qualitative research methods.", "Chúng tôi sử dụng phương pháp nghiên cứu định tính."),
                ("quantitative", "adj", "định lượng", "Quantitative data supports the claim.", "Dữ liệu định lượng hỗ trợ tuyên bố."),
                ("variable", "n", "biến số", "The independent variable was temperature.", "Biến độc lập là nhiệt độ."),
                ("sample", "n", "mẫu", "A random sample of 500 participants.", "Mẫu ngẫu nhiên gồm 500 người tham gia."),
            ],
            "Exams & University": [
                ("enrollment", "n", "đăng ký nhập học", "Enrollment opens in September.", "Đăng ký nhập học mở vào tháng 9."),
                ("scholarship", "n", "học bổng", "She won a full scholarship.", "Cô ấy giành được học bổng toàn phần."),
                ("curriculum", "n", "chương trình giảng dạy", "The curriculum includes math and science.", "Chương trình bao gồm toán và khoa học."),
                ("semester", "n", "học kỳ", "The spring semester starts in February.", "Học kỳ xuân bắt đầu vào tháng 2."),
                ("lecture", "n", "bài giảng", "The lecture was very informative.", "Bài giảng rất có giá trị."),
                ("tutor", "n", "gia sư", "She hired a tutor for math.", "Cô ấy thuê gia sư toán."),
                ("assignment", "n", "bài tập", "The assignment is due next Monday.", "Bài tập hạn nộp thứ Hai tới."),
                ("diploma", "n", "bằng tốt nghiệp", "He received his diploma in June.", "Anh ấy nhận bằng tốt nghiệp vào tháng 6."),
                ("extracurricular", "adj", "ngoại khóa", "Extracurricular activities build character.", "Hoạt động ngoại khóa rèn luyện tính cách."),
                ("GPA", "n", "điểm trung bình", "Her GPA is 3.8 out of 4.0.", "Điểm trung bình của cô ấy là 3.8/4.0."),
            ],
        },
    },

    # ── Parent: Travel & Tourism ──
    "Travel & Tourism": {
        "order_index": 17,
        "icon_url": "✈️",
        "color_hex": "#1ABC9C",
        "description": "Từ vựng du lịch, đặt phòng, di chuyển",
        "children": {
            "At the Airport": [
                ("boarding pass", "n", "thẻ lên máy bay", "Please show your boarding pass.", "Vui lòng xuất trình thẻ lên máy bay."),
                ("customs", "n", "hải quan", "We passed through customs quickly.", "Chúng tôi qua hải quan nhanh chóng."),
                ("departure", "n", "khởi hành", "The departure time is 9 AM.", "Giờ khởi hành là 9 giờ sáng."),
                ("terminal", "n", "nhà ga", "Our flight departs from Terminal 2.", "Chuyến bay của chúng tôi ở nhà ga 2."),
                ("luggage", "n", "hành lý", "Don't forget to collect your luggage.", "Đừng quên lấy hành lý."),
                ("check-in", "n", "thủ tục đăng ký", "Online check-in is available.", "Đăng ký trực tuyến có sẵn."),
                ("passport", "n", "hộ chiếu", "Your passport must be valid.", "Hộ chiếu phải còn hiệu lực."),
                ("visa", "n", "thị thực", "Do I need a visa for Japan?", "Tôi có cần thị thực đi Nhật không?"),
                ("layover", "n", "quá cảnh", "We have a 3-hour layover in Bangkok.", "Chúng tôi quá cảnh 3 tiếng ở Bangkok."),
                ("turbulence", "n", "nhiễu loạn không khí", "The plane experienced some turbulence.", "Máy bay gặp nhiễu loạn."),
                ("jet lag", "n", "lệch múi giờ", "It takes a few days to recover from jet lag.", "Cần vài ngày để hồi phục sau lệch múi giờ."),
                ("duty-free", "adj", "miễn thuế", "I bought perfume at the duty-free shop.", "Tôi mua nước hoa ở cửa hàng miễn thuế."),
            ],
            "Hotel & Accommodation": [
                ("reservation", "n", "đặt phòng", "I have a reservation under my name.", "Tôi có đặt phòng dưới tên tôi."),
                ("suite", "n", "phòng hạng sang", "They booked a luxury suite.", "Họ đặt phòng suite sang trọng."),
                ("concierge", "n", "lễ tân", "Ask the concierge for restaurant tips.", "Hỏi lễ tân gợi ý nhà hàng."),
                ("checkout", "n", "trả phòng", "Checkout time is noon.", "Giờ trả phòng là buổi trưa."),
                ("amenities", "n", "tiện nghi", "The hotel has great amenities.", "Khách sạn có tiện nghi tuyệt vời."),
                ("complimentary", "adj", "miễn phí", "Breakfast is complimentary.", "Bữa sáng miễn phí."),
                ("vacancy", "n", "phòng trống", "Do you have any vacancies?", "Bạn có phòng trống không?"),
                ("receptionist", "n", "nhân viên lễ tân", "The receptionist was very helpful.", "Lễ tân rất hỗ trợ nhiệt tình."),
                ("housekeeping", "n", "dịch vụ phòng", "Please call housekeeping.", "Vui lòng gọi dịch vụ phòng."),
                ("brochure", "n", "tờ rơi quảng cáo", "Pick up a tourist brochure.", "Lấy một tờ rơi du lịch."),
            ],
        },
    },

    # ── Parent: Health & Medicine ──
    "Health & Medicine": {
        "order_index": 18,
        "icon_url": "🏥",
        "color_hex": "#E74C3C",
        "description": "Từ vựng y tế, sức khỏe, triệu chứng và điều trị",
        "children": {
            "Symptoms & Diseases": [
                ("symptom", "n", "triệu chứng", "Fever is a common symptom.", "Sốt là triệu chứng phổ biến."),
                ("diagnosis", "n", "chẩn đoán", "The diagnosis was confirmed.", "Chẩn đoán đã được xác nhận."),
                ("allergy", "n", "dị ứng", "She has a peanut allergy.", "Cô ấy dị ứng đậu phộng."),
                ("chronic", "adj", "mãn tính", "He has a chronic back pain.", "Anh ấy bị đau lưng mãn tính."),
                ("contagious", "adj", "truyền nhiễm", "The flu is highly contagious.", "Cúm rất dễ lây."),
                ("epidemic", "n", "dịch bệnh", "The epidemic spread rapidly.", "Dịch bệnh lan rộng nhanh chóng."),
                ("fatigue", "n", "mệt mỏi", "Fatigue is a sign of overwork.", "Mệt mỏi là dấu hiệu làm việc quá sức."),
                ("infection", "n", "nhiễm trùng", "The wound got an infection.", "Vết thương bị nhiễm trùng."),
                ("inflammation", "n", "viêm", "Inflammation causes redness and swelling.", "Viêm gây đỏ và sưng."),
                ("insomnia", "n", "mất ngủ", "She suffers from insomnia.", "Cô ấy bị mất ngủ."),
            ],
            "Treatment & Medicine": [
                ("prescription", "n", "đơn thuốc", "The doctor wrote a prescription.", "Bác sĩ viết đơn thuốc."),
                ("vaccine", "n", "vắc-xin", "The vaccine prevents the disease.", "Vắc-xin ngăn ngừa bệnh."),
                ("surgery", "n", "phẫu thuật", "The surgery was successful.", "Ca phẫu thuật thành công."),
                ("therapy", "n", "liệu pháp", "Physical therapy helps recovery.", "Vật lý trị liệu giúp hồi phục."),
                ("antibiotic", "n", "kháng sinh", "Don't overuse antibiotics.", "Không nên lạm dụng kháng sinh."),
                ("dosage", "n", "liều lượng", "Follow the recommended dosage.", "Tuân theo liều lượng khuyến nghị."),
                ("side effect", "n", "tác dụng phụ", "This medicine has few side effects.", "Thuốc này ít tác dụng phụ."),
                ("rehabilitation", "n", "phục hồi chức năng", "Rehabilitation takes several months.", "Phục hồi chức năng mất vài tháng."),
                ("first aid", "n", "sơ cứu", "Everyone should learn first aid.", "Mọi người nên học sơ cứu."),
                ("check-up", "n", "khám sức khỏe", "Get a regular health check-up.", "Hãy khám sức khỏe định kỳ."),
            ],
        },
    },
}


def main():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    total_topics = 0
    total_words = 0

    for parent_name, pdata in NEW_DATA.items():
        parent_id = gen_id()

        # Insert parent topic
        c.execute(
            '''INSERT OR IGNORE INTO topics (id, name, description, icon_url, color_hex,
               total_words, learned_words, is_unlocked, order_index, parent_id)
               VALUES (?, ?, ?, ?, ?, 0, 0, 1, ?, NULL)''',
            (parent_id, parent_name, pdata['description'],
             pdata['icon_url'], pdata['color_hex'], pdata['order_index']),
        )
        total_topics += 1
        print(f'📁 Parent: {parent_name}')

        parent_total_words = 0

        for child_name, words_list in pdata['children'].items():
            child_id = gen_id()

            # Insert child topic
            c.execute(
                '''INSERT OR IGNORE INTO topics (id, name, description, icon_url, color_hex,
                   total_words, learned_words, is_unlocked, order_index, parent_id)
                   VALUES (?, ?, ?, ?, ?, ?, 0, 1, 0, ?)''',
                (child_id, child_name, child_name,
                 pdata['icon_url'], pdata['color_hex'],
                 len(words_list), parent_id),
            )
            total_topics += 1

            for word_data in words_list:
                word, pos, meaning, example, example_vi = word_data
                word_id = gen_id()

                c.execute(
                    '''INSERT OR IGNORE INTO words
                       (id, word, meaning, pronunciation, example, a_topic_id,
                        is_learned, is_favorite, pos)
                       VALUES (?, ?, ?, '', ?, ?, 1, 0, ?)''',
                    (word_id, word, meaning, example, child_id, pos),
                )
                total_words += 1

            parent_total_words += len(words_list)
            print(f'   📄 {child_name} → {len(words_list)} từ')

        # Update parent total_words
        c.execute(
            'UPDATE topics SET total_words = ? WHERE id = ?',
            (parent_total_words, parent_id),
        )

    conn.commit()
    conn.close()

    print(f'\n✅ Hoàn thành! Thêm {total_topics} topics, {total_words} từ vựng mới.')
    print(f'📊 DB giờ có tổng cộng nhiều hơn dữ liệu!')


if __name__ == '__main__':
    main()
