using Microsoft.AspNetCore.Mvc;
using msrpaazure;
using System.Threading.Tasks;

namespace msrpawebapi
{
    [Produces("application/json")]
    [Route("api/[controller]")]
    [ApiController]
    public class GraphController : ControllerBase
    {
        private readonly SearchConfig _searchConfig;

        public GraphController(SearchConfig searchConfig)
        {
            _searchConfig = searchConfig;
        }

        [HttpGet]
        [HttpGet("{facet}")]
        public async Task<IActionResult> Get(string facet, string query)
        {
            if (string.IsNullOrWhiteSpace(query))
            {
                query = "*";
            }

            if (string.IsNullOrWhiteSpace(facet))
            {
                facet = "keyPhrases";
            }

            var graphJson = await FacetGraphGenerator.GetGraphNodes(_searchConfig, query, facet);

            return new JsonResult(graphJson);
        }
    }
}