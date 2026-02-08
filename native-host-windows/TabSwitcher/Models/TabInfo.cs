using System.Windows.Media.Imaging;

namespace TabSwitcher.Models
{
    public class TabInfo
    {
        public int Id { get; set; }
        public string Title { get; set; } = "";
        public string FavIconUrl { get; set; } = "";
        public BitmapImage? Thumbnail { get; set; }
        public string Url { get; set; } = "";
    }
}
