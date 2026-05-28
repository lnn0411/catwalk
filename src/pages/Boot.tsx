import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

const Boot = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const timer = window.setTimeout(() => navigate('/loading'), 600);

    return () => window.clearTimeout(timer);
  }, [navigate]);

  return <div>S00 开机启动</div>;
};

export default Boot;
