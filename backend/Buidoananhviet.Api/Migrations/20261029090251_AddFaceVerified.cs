using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Buidoananhviet.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddFaceVerified : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "CheckOutFaceVerified",
                table: "Attendances",
                type: "bit",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "FaceVerified",
                table: "Attendances",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CheckOutFaceVerified",
                table: "Attendances");

            migrationBuilder.DropColumn(
                name: "FaceVerified",
                table: "Attendances");
        }
    }
}
