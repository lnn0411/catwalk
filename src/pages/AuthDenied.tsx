import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

const AuthDenied = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const timer = window.setTimeout(() => navigate('/garden'), 600);

    return () => window.clearTimeout(timer);
  }, [navigate]);

  return <div>S12 未授权计步</div>;
};

export default AuthDenied;
