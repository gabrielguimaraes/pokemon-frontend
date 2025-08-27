import React from 'react';
import './FilterBar.css';

const FilterBar = ({ filters, types, onFilterChange, onClearFilters }) => {
  const handleInputChange = (field, value) => {
    onFilterChange({
      ...filters,
      [field]: value
    });
  };

  const hasActiveFilters = filters.name || filters.type || filters.legendary;

  return (
    <div className="filter-bar">
      <div className="filter-section">
        <label htmlFor="name-filter" className="filter-label">
          Search by Name:
        </label>
        <input
          id="name-filter"
          type="text"
          placeholder="Enter Pokemon name..."
          value={filters.name}
          onChange={(e) => handleInputChange('name', e.target.value)}
          className="filter-input"
        />
      </div>

      <div className="filter-section">
        <label htmlFor="type-filter" className="filter-label">
          Filter by Type:
        </label>
        <select
          id="type-filter"
          value={filters.type}
          onChange={(e) => handleInputChange('type', e.target.value)}
          className="filter-select"
        >
          <option value="">All Types</option>
          {types.map(type => (
            <option key={type} value={type}>
              {type}
            </option>
          ))}
        </select>
      </div>

      <div className="filter-section">
        <label htmlFor="legendary-filter" className="filter-label">
          Legendary Status:
        </label>
        <select
          id="legendary-filter"
          value={filters.legendary}
          onChange={(e) => handleInputChange('legendary', e.target.value)}
          className="filter-select"
        >
          <option value="">All Pokemon</option>
          <option value="true">Legendary Only</option>
          <option value="false">Non-Legendary Only</option>
        </select>
      </div>

      {hasActiveFilters && (
        <div className="filter-section">
          <button
            onClick={onClearFilters}
            className="clear-filters-button"
            title="Clear all filters"
          >
            Clear Filters
          </button>
        </div>
      )}
    </div>
  );
};

export default FilterBar;
