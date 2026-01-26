// decode.js 内容
function decodeHexToPrivateKey(hexString) {
    // 移除空格
    const hex = hexString.replace(/ /g, '');
    
    // 十六进制转 ASCII
    let ascii = '';
    for (let i = 0; i < hex.length; i += 2) {
        ascii += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
    }
    
    console.log('ASCII:', ascii);
    
    // Base64 解码（浏览器环境用 atob，Node.js 用 Buffer）
    const privateKeyRaw = Buffer.from(ascii, 'base64').toString();
    // 确保私钥没有重复的 0x 前缀
    const cleanedPrivateKey = privateKeyRaw.startsWith('0x') ? privateKeyRaw.slice(2) : privateKeyRaw;
    console.log('Private Key:', '0x' + cleanedPrivateKey);
    
    // 验证地址
    const Web3Import = require('web3');
    const Web3 = Web3Import.default || Web3Import;
    const web3 = new Web3();
    const account = web3.eth.accounts.privateKeyToAccount('0x' + cleanedPrivateKey);
    console.log('Address:', account.address);

    return {
        privateKey: '0x' + cleanedPrivateKey,
        address: account.address
    };
}

// 测试数据
const hex1 = "4d 48 67 33 5a 44 45 31 59 6d 4a 68 4d 6a 5a 6a 4e 54 49 7a 4e 6a 67 7a 59 6d 5a 6a 4d 32 52 6a 4e 32 4e 6b 59 7a 56 6b 4d 57 49 34 59 54 49 33 4e 44 51 30 4e 44 63 31 4f 54 64 6a 5a 6a 52 6b 59 54 45 33 4d 44 56 6a 5a 6a 5a 6a 4f 54 6b 7a 4d 44 59 7a 4e 7a 51 30";
console.log('Decoding Key 1:');
decodeHexToPrivateKey(hex1);
const hex2 = "4d 48 67 32 4f 47 4a 6b 4d 44 49 77 59 57 51 78 4f 44 5a 69 4e 6a 51 33 59 54 59 35 4d 57 4d 32 59 54 56 6a 4d 47 4d 78 4e 54 49 35 5a 6a 49 78 5a 57 4e 6b 4d 44 6c 6b 59 32 4d 30 4e 54 49 30 4d 54 51 77 4d 6d 46 6a 4e 6a 42 69 59 54 4d 33 4e 32 4d 30 4d 54 55 35";
console.log('Decoding Key 2:');
decodeHexToPrivateKey(hex2);