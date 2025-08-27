import React from 'react';
import './LoadingSpinner.css';

const LoadingSpinner = () => {
  return (
    <div className="loading-container">
      <div className="pokeball-spinner">
        <div className="pokeball">
          <div className="pokeball-top"></div>
          <div className="pokeball-middle"></div>
          <div className="pokeball-bottom"></div>
          <div className="pokeball-center">
            <div className="pokeball-inner-center"></div>
          </div>
        </div>
      </div>
      <p className="loading-text">Loading Pokemon...</p>
    </div>
  );
};

export default LoadingSpinner;
