import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

const Onboarding = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const timer = window.setTimeout(() => navigate('/auth-denied'), 600);

    return () => window.clearTimeout(timer);
  }, [navigate]);

  return <div>S01 引导页1-3</div>;
};

export default Onboarding;
