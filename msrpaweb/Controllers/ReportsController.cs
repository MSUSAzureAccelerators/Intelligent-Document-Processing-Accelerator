using Microsoft.AspNetCore.Mvc;

namespace msrpaweb
{
    public class ReportsController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}