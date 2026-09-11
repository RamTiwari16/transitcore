import * as CryptoJS from 'crypto-js';

const SECRET_KEY = 'SISCOCASHTODAY#!@#$%^12131'; 

export class CryptoUtil {
  
  static encryptData(data: any): string {
    try {
      return CryptoJS.AES.encrypt(
        JSON.stringify(data),
        SECRET_KEY
      ).toString();
    } catch (e) {
     
      return '';
    }
  }

  static decryptData(data: string): any {
    try {
      const bytes = CryptoJS.AES.decrypt(data, SECRET_KEY);
      if (bytes.toString()) {
        return JSON.parse(bytes.toString(CryptoJS.enc.Utf8));
      }
      return null;
    } catch (e) {
      console.error('Decryption Error:', e);
      return null;
    }
  }
}
