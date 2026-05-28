interface CurrencyBarProps {
  coins: number;
  gems: number;
  hearts?: number;
}

const CurrencyBar = ({ coins, gems, hearts }: CurrencyBarProps) => (
  <div className="currency-bar" aria-label="Currencies">
    <span className="currency-bar__item">金币 {coins}</span>
    <span className="currency-bar__item">宝石 {gems}</span>
    {typeof hearts === 'number' ? (
      <span className="currency-bar__item">爱心 {hearts}</span>
    ) : null}
  </div>
);

export default CurrencyBar;
