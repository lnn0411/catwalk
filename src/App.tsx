import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import BottomNav from './components/BottomNav';
import CurrencyBar from './components/CurrencyBar';
import DevTools from './components/DevTools';
import EnergyBar from './components/EnergyBar';
import { useEnergy } from './hooks/useEnergy';
import AuthDenied from './pages/AuthDenied';
import Boot from './pages/Boot';
import Dex from './pages/Dex';
import Dormant from './pages/Dormant';
import Garden from './pages/Garden';
import HatchComplete from './pages/HatchComplete';
import Hatchery from './pages/Hatchery';
import Loading from './pages/Loading';
import NameCat from './pages/NameCat';
import NetworkError from './pages/NetworkError';
import Onboarding from './pages/Onboarding';

function App() {
  const { energy, maxEnergy } = useEnergy();

  return (
    <BrowserRouter>
      <div className="app-shell">
        <CurrencyBar coins={0} gems={0} hearts={0} />
        <EnergyBar current={energy} max={maxEnergy} variant="blue" />
        <main className="page-shell">
          <Routes>
            <Route path="/" element={<Navigate to="/boot" replace />} />
            <Route path="/boot" element={<Boot />} />
            <Route path="/loading" element={<Loading />} />
            <Route path="/onboarding" element={<Onboarding />} />
            <Route path="/auth-denied" element={<AuthDenied />} />
            <Route path="/network-error" element={<NetworkError />} />
            <Route path="/dormant" element={<Dormant />} />
            <Route path="/garden" element={<Garden />} />
            <Route path="/hatchery" element={<Hatchery />} />
            <Route path="/hatch-complete" element={<HatchComplete />} />
            <Route path="/name-cat" element={<NameCat />} />
            <Route path="/dex" element={<Dex />} />
          </Routes>
        </main>
        <BottomNav />
        <DevTools />
      </div>
    </BrowserRouter>
  );
}

export default App;
