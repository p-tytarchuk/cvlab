// Proves OpenCV works: constructs a Mat, resizes it, and checks actual pixel
// values. Linking alone is not enough - a broken build can link and then
// produce wrong pixels, so every assertion here is on data.

#include <gtest/gtest.h>

#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <vector>

TEST(OpenCVSmoke, MatConstruction) {
  cv::Mat m(4, 6, CV_8UC1, cv::Scalar(7));

  EXPECT_EQ(m.rows, 4);
  EXPECT_EQ(m.cols, 6);
  EXPECT_EQ(m.channels(), 1);
  EXPECT_EQ(m.type(), CV_8UC1);
  EXPECT_FALSE(m.empty());
  EXPECT_EQ(m.at<uchar>(0, 0), 7);
  EXPECT_EQ(m.at<uchar>(3, 5), 7);
}

TEST(OpenCVSmoke, ResizeChangesGeometry) {
  cv::Mat src(10, 10, CV_8UC3, cv::Scalar(0, 0, 0));
  cv::Mat dst;

  cv::resize(src, dst, cv::Size(5, 20), 0, 0, cv::INTER_NEAREST);

  EXPECT_EQ(dst.cols, 5);
  EXPECT_EQ(dst.rows, 20);
  EXPECT_EQ(dst.type(), src.type());
}

// Nearest-neighbour upscaling by an integer factor must replicate pixels
// exactly. This is a real numerical check on the resize result.
TEST(OpenCVSmoke, NearestNeighbourUpscalePreservesValues) {
  cv::Mat src(2, 2, CV_8UC1);
  src.at<uchar>(0, 0) = 10;
  src.at<uchar>(0, 1) = 20;
  src.at<uchar>(1, 0) = 30;
  src.at<uchar>(1, 1) = 40;

  cv::Mat dst;
  cv::resize(src, dst, cv::Size(4, 4), 0, 0, cv::INTER_NEAREST);

  ASSERT_EQ(dst.rows, 4);
  ASSERT_EQ(dst.cols, 4);

  // Each source pixel becomes a 2x2 block.
  EXPECT_EQ(dst.at<uchar>(0, 0), 10);
  EXPECT_EQ(dst.at<uchar>(1, 1), 10);
  EXPECT_EQ(dst.at<uchar>(0, 3), 20);
  EXPECT_EQ(dst.at<uchar>(3, 0), 30);
  EXPECT_EQ(dst.at<uchar>(3, 3), 40);
}

// Averaging a uniform image must return exactly that value: proves imgproc
// arithmetic is wired up, not just the headers.
TEST(OpenCVSmoke, MeanOfUniformImage) {
  cv::Mat m(8, 8, CV_8UC1, cv::Scalar(100));
  const cv::Scalar mean = cv::mean(m);
  EXPECT_DOUBLE_EQ(mean[0], 100.0);
}

TEST(OpenCVSmoke, ColorConversionProducesExpectedGray) {
  // Pure blue in BGR; OpenCV's BGR2GRAY weight for blue is 0.114.
  cv::Mat bgr(1, 1, CV_8UC3, cv::Scalar(255, 0, 0));
  cv::Mat gray;

  cv::cvtColor(bgr, gray, cv::COLOR_BGR2GRAY);

  ASSERT_EQ(gray.type(), CV_8UC1);
  EXPECT_NEAR(gray.at<uchar>(0, 0), 29, 1);  // 0.114 * 255 ~= 29
}

// imgcodecs is in BUILD_LIST, so prove it round-trips through memory (no file
// I/O, so the test stays hermetic and needs no temp directory).
TEST(OpenCVSmoke, ImgcodecsEncodeDecodeRoundTrip) {
  cv::Mat src(4, 4, CV_8UC1, cv::Scalar(123));

  std::vector<uchar> buf;
  ASSERT_TRUE(cv::imencode(".png", src, buf));
  EXPECT_FALSE(buf.empty());

  const cv::Mat decoded = cv::imdecode(buf, cv::IMREAD_GRAYSCALE);
  ASSERT_FALSE(decoded.empty());
  EXPECT_EQ(decoded.rows, 4);
  EXPECT_EQ(decoded.cols, 4);
  EXPECT_EQ(decoded.at<uchar>(2, 2), 123);  // PNG is lossless
}
