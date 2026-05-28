import { NavLink } from 'react-router-dom';

const tabs = [
  { label: '花园', to: '/garden' },
  { label: '图鉴', to: '/dex' },
  { label: '孵化器', to: '/hatchery' },
  { label: '商店', to: '/network-error' },
  { label: '设置', to: '/auth-denied' },
];

const BottomNav = () => (
  <nav className="bottom-nav" aria-label="Bottom navigation">
    {tabs.map((tab) => (
      <NavLink
        key={tab.label}
        to={tab.to}
        className={({ isActive }) =>
          `bottom-nav__tab${isActive ? ' bottom-nav__tab--active' : ''}`
        }
      >
        {tab.label}
      </NavLink>
    ))}
  </nav>
);

export default BottomNav;
