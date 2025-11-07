const fs = require('fs');
const csv = require('csv-parser');
const admin = require('firebase-admin');

// Nạp file key bạn vừa tải về
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const collectionRef = db.collection('foods'); // Tên collection trên Firestore
const batch = db.batch(); // Sử dụng batch để ghi nhanh hơn
let count = 0;

// Đảm bảo tên file này khớp với file CSV của bạn
fs.createReadStream('./mon_an.csv')
  .pipe(csv()) // Tự động đọc tiêu đề (ten_mon, calo, ...)
  .on('data', (row) => {
    // Xử lý từng hàng
    const foodData = {
      name: row.ten_mon,
      // Chuyển đổi sang kiểu số (float), nếu lỗi thì mặc định là 0
      calories: parseFloat(row.calo) || 0,
      protein: parseFloat(row.protein) || 0,
      fat: parseFloat(row.fat) || 0,
      carbs: parseFloat(row.carb) || 0,
      fiber: parseFloat(row.fiber) || 0,
      unit: row.so_luong,
      // Tạo trường để tìm kiếm (viết thường)
      searchName: row.ten_mon ? row.ten_mon.toLowerCase() : ""
    };

    // Thêm vào một batch (gói)
    const docRef = collectionRef.doc(); // Tự tạo ID
    batch.set(docRef, foodData);
    count++;

    // Ghi batch lên server mỗi 500 món ăn
    if (count % 500 === 0) {
      batch.commit().then(() => {
        console.log(`Đã đẩy 500 bản ghi...`);
      });
      batch = db.batch(); // Tạo batch mới
    }
  })
  .on('end', () => {
    // Ghi phần còn lại
    batch.commit().then(() => {
      console.log(`*** NHẬP HOÀN TẤT! Đã thêm tổng cộng ${count} món ăn. ***`);
    });
  });