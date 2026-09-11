using System;
using System.Collections.Generic;
using System.Text;

namespace BharatEMart.Core.Models
{
    internal class BharatEMartDto
    {
    }
    public class VehicleOrderMappingDto
    {
        public string VehicleNo { get; set; }

        public string OrderNo { get; set; }

        public DateOnly UploadDate { get; set; }

        public string CreatedByEmail { get; set; }
    }
    public class VehicleOrderMappingResponseDto
    {
        public int Id { get; set; }

        public string VehicleNo { get; set; }

        public string OrderNo { get; set; }

        public DateOnly UploadDate { get; set; }

        public string CreatedByEmail { get; set; }

        public DateTime CreatedAt { get; set; }
    }

    public class DateRangeRequestDto
    {
        public DateOnly FromDate { get; set; }

        public DateOnly ToDate { get; set; }
    }
}
