import { FormEvent, useState } from 'react';
import { ShieldCheck } from 'lucide-react';

import type { AdminApi } from '../api';
import type { AdminSession } from '../types';

export function LoginScreen({
  api,
  onLogin,
}: {
  api: AdminApi;
  onLogin: (session: AdminSession) => void;
}) {
  const [email, setEmail] = useState('admin@roamy.local');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);
    try {
      onLogin(await api.login(email, password));
    } catch (loginError) {
      setError(
        loginError instanceof Error ? loginError.message : 'Đăng nhập thất bại',
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-page">
      <form className="login-card" onSubmit={submit}>
        <div className="brand-mark large">R</div>
        <h1>Roamy Admin</h1>
        <p>Đăng nhập để xem dữ liệu, lỗi phản hồi và hoạt động hệ thống.</p>
        <label>
          Email admin
          <input value={email} onChange={(event) => setEmail(event.target.value)} />
        </label>
        <label>
          Mật khẩu
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            placeholder="ADMIN_PASSWORD"
          />
        </label>
        {error && <div className="form-error">{error}</div>}
        <button className="primary-button" disabled={loading} type="submit">
          <ShieldCheck size={18} />
          {loading ? 'Đang kiểm tra...' : 'Đăng nhập'}
        </button>
      </form>
    </main>
  );
}
