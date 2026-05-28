import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

const Loading = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const timer = window.setTimeout(() => navigate('/onboarding'), 600);

    return () => window.clearTimeout(timer);
  }, [navigate]);

  return <div>S02 加载页</div>;
};

export default Loading;
