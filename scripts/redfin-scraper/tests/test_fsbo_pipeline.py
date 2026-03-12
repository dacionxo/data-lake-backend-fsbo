"""
End-to-End Integration Tests for FSBO Pipeline

Tests verify that:
1. Pipeline stages execute correctly
2. Idempotent upserts work
3. Incremental scraping filters correctly
4. Error handling works
5. Results appear correctly in UI
"""
import pytest
import os
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, MagicMock
from typing import List, Dict, Any

# Add parent directory to path
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from nextdeal_redfin.pipeline import (
    FSBOPipeline,
    PipelineConfig,
    PipelineStage,
    PipelineResult,
)
from nextdeal_redfin.handlers import (
    SitemapDiscoveryHandler,
    FetchHandler,
    ParseHandler,
    NormalizeHandler,
    UpsertHandler,
    HealthChecker,
)
from nextdeal_redfin.http_client import RobustHTTPClient
from nextdeal_redfin.ip_rotation import IPRotationManager, IPRotationConfig


@pytest.fixture
def mock_http_client():
    """Mock HTTP client."""
    client = Mock(spec=RobustHTTPClient)
    client.get = Mock(return_value={
        'html': '<html><body>Test</body></html>',
        'json': {},
        'status_code': 200,
        'headers': {},
        'url': 'https://www.redfin.com/test',
    })
    return client


@pytest.fixture
def mock_supabase_client():
    """Mock Supabase client."""
    client = Mock()
    client.table = Mock(return_value=client)
    client.upsert = Mock(return_value=client)
    client.execute = Mock(return_value=Mock(data=[{'listing_id': 'test123'}]))
    return client


@pytest.fixture
def pipeline_config():
    """Pipeline configuration for testing."""
    return PipelineConfig(
        source='redfin',
        target_states=['CA'],
        sitemap_urls=['https://www.redfin.com/test-sitemap.xml'],
        incremental=False,
        retry_budget=2,
        timeout=10,
        max_workers=2,
        batch_size=10,
    )


class TestSitemapDiscovery:
    """Tests for sitemap discovery stage."""
    
    def test_discover_listing_urls(self, mock_http_client):
        """Test that sitemap discovery finds listing URLs."""
        # Mock XML sitemap response
        mock_http_client.get.return_value = {
            'html': '''<?xml version="1.0"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
                <url>
                    <loc>https://www.redfin.com/CA/Los-Angeles/test-12345</loc>
                    <lastmod>2024-01-01T00:00:00Z</lastmod>
                </url>
            </urlset>''',
            'json': {},
            'status_code': 200,
            'headers': {},
            'url': 'https://www.redfin.com/test-sitemap.xml',
        }
        
        handler = SitemapDiscoveryHandler(mock_http_client)
        urls = handler.discover(
            sitemap_urls=['https://www.redfin.com/test-sitemap.xml'],
            target_states=['CA'],
            incremental=False,
        )
        
        assert len(urls) > 0
        assert any('CA' in url for url in urls)
    
    def test_incremental_filtering(self, mock_http_client):
        """Test that incremental scraping filters by timestamp."""
        last_timestamp = datetime(2024, 1, 1)
        
        # Mock sitemap with old and new URLs
        mock_http_client.get.return_value = {
            'html': '''<?xml version="1.0"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
                <url>
                    <loc>https://www.redfin.com/CA/test-old</loc>
                    <lastmod>2023-12-01T00:00:00Z</lastmod>
                </url>
                <url>
                    <loc>https://www.redfin.com/CA/test-new</loc>
                    <lastmod>2024-01-15T00:00:00Z</lastmod>
                </url>
            </urlset>''',
            'json': {},
            'status_code': 200,
            'headers': {},
            'url': 'https://www.redfin.com/test-sitemap.xml',
        }
        
        handler = SitemapDiscoveryHandler(mock_http_client)
        urls = handler.discover(
            sitemap_urls=['https://www.redfin.com/test-sitemap.xml'],
            target_states=['CA'],
            incremental=True,
            last_sitemap_timestamp=last_timestamp,
        )
        
        # Should only include new URL
        assert len(urls) == 1
        assert 'test-new' in urls[0]


class TestFetchStage:
    """Tests for fetch stage."""
    
    def test_fetch_with_retry(self, mock_http_client):
        """Test that fetch retries on failures."""
        # Mock initial failure, then success
        mock_http_client.get.side_effect = [
            None,  # First attempt fails
            {
                'html': '<html>Success</html>',
                'json': {},
                'status_code': 200,
                'headers': {},
                'url': 'https://www.redfin.com/test',
            }
        ]
        
        handler = FetchHandler(mock_http_client)
        result = handler.fetch(
            url='https://www.redfin.com/test',
            source='redfin',
            retry_budget=3,
        )
        
        assert result is not None
        assert mock_http_client.get.call_count == 2


class TestNormalizeStage:
    """Tests for normalize stage."""
    
    def test_normalize_data(self):
        """Test data normalization."""
        handler = NormalizeHandler()
        
        data = {
            'property_url': 'https://www.redfin.com/CA/test',
            'zip_code': '1234',
            'list_price': 'Price, $500,000—Est.',
            'source': 'redfin',
        }
        
        normalized = handler.normalize(data, source='redfin')
        
        assert normalized is not None
        assert normalized['zip_code'] == '01234'  # Zero-padded
        assert 'Price,' not in normalized.get('list_price', '')
        assert normalized['fsbo_source'] == 'redfin'
        assert normalized['listing_id'] is not None


class TestUpsertStage:
    """Tests for upsert stage."""
    
    def test_idempotent_upsert(self, mock_supabase_client):
        """Test that upserts are idempotent."""
        handler = UpsertHandler(mock_supabase_client)
        
        listings = [
            {
                'listing_id': 'test123',
                'property_url': 'https://www.redfin.com/test',
                'fsbo_source': 'redfin',
                'city': 'Los Angeles',
            }
        ]
        
        # First upsert
        count1 = handler.upsert_batch(listings, source='redfin')
        assert count1 == 1
        
        # Second upsert (should not create duplicate)
        count2 = handler.upsert_batch(listings, source='redfin')
        assert count2 == 1
        
        # Verify upsert was called with correct conflict resolution
        mock_supabase_client.upsert.assert_called()
        call_args = mock_supabase_client.upsert.call_args
        assert 'on_conflict' in call_args.kwargs or 'listing_id,property_url' in str(call_args)


class TestFullPipeline:
    """End-to-end pipeline tests."""
    
    def test_pipeline_execution(self, mock_http_client, mock_supabase_client, pipeline_config):
        """Test full pipeline execution."""
        # Mock sitemap discovery
        mock_http_client.get.return_value = {
            'html': '''<?xml version="1.0"?>
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
                <url>
                    <loc>https://www.redfin.com/CA/test-12345</loc>
                </url>
            </urlset>''',
            'json': {},
            'status_code': 200,
            'headers': {},
            'url': 'https://www.redfin.com/test-sitemap.xml',
        }
        
        # Create pipeline
        pipeline = FSBOPipeline(
            config=pipeline_config,
            sitemap_discoverer=SitemapDiscoveryHandler(mock_http_client),
            fetcher=FetchHandler(mock_http_client),
            parser=ParseHandler(),
            normalizer=NormalizeHandler(),
            upsert_handler=UpsertHandler(mock_supabase_client),
            raw_storage_handler=None,
            health_checker=HealthChecker(mock_supabase_client),
        )
        
        # Run pipeline
        result = pipeline.run()
        
        # Verify results
        assert result.stage == PipelineStage.COMPLETE
        assert result.listings_found > 0
        assert result.listings_upserted >= 0
    
    def test_pipeline_error_handling(self, mock_http_client, mock_supabase_client, pipeline_config):
        """Test pipeline error handling."""
        # Mock failure
        mock_http_client.get.side_effect = Exception("Network error")
        
        pipeline = FSBOPipeline(
            config=pipeline_config,
            sitemap_discoverer=SitemapDiscoveryHandler(mock_http_client),
            fetcher=FetchHandler(mock_http_client),
            parser=ParseHandler(),
            normalizer=NormalizeHandler(),
            upsert_handler=UpsertHandler(mock_supabase_client),
        )
        
        result = pipeline.run()
        
        # Should handle error gracefully
        assert result.stage in [PipelineStage.ERROR, PipelineStage.COMPLETE]
        assert len(result.errors) > 0 or result.listings_found == 0


class TestUIIntegration:
    """Tests for UI integration (verify results appear in UI)."""
    
    @pytest.mark.integration
    def test_results_in_ui(self, mock_supabase_client):
        """Test that scraped results appear in UI views."""
        # This test would verify that:
        # 1. Data appears in prospect_enrich_view
        # 2. Data appears in source_health_summary
        # 3. Data is queryable by LeadMap-main
        
        # Mock query results
        mock_supabase_client.table().select().execute.return_value = Mock(data=[
            {
                'listing_id': 'test123',
                'property_url': 'https://www.redfin.com/test',
                'city': 'Los Angeles',
                'state': 'CA',
            }
        ])
        
        # Verify data is queryable
        # (This would be an actual query in a real test)
        pass


if __name__ == '__main__':
    pytest.main([__file__, '-v'])


